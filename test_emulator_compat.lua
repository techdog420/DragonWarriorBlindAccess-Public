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
    "DW_BIZHAWK_NATIVE_API",
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

local function find_source(sources, name)
    for _, source in ipairs(sources or {}) do
        if source.name == name then
            return source
        end
    end
    return nil
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
        read_bytes_as_binary_string = function(address, length, domain)
            local domain_bytes = domains[domain]
            if not domain_bytes then
                error("unknown domain: " .. tostring(domain))
            end
            local bytes = {}
            for i = 0, length - 1 do
                bytes[i + 1] = string.char(domain_bytes[address + i] or 0)
            end
            return table.concat(bytes)
        end,
        write_u8 = function() end,
    }
    _G.mainmemory = {
        read_u8 = function()
            return 0
        end,
        write_u8 = function() end,
    }
    local joypad_state = {}
    local joypad_sets = {}
    local input_state = {}
    local ppu_reads = 0

    _G.joypad = {
        get = function()
            return joypad_state
        end,
        set = function(buttons, controller)
            joypad_sets[#joypad_sets + 1] = {
                buttons = buttons,
                controller = controller,
            }
        end,
    }
    _G.input = {
        get = function()
            return input_state
        end,
    }
    _G.console = {
        log = function(message)
            logs[#logs + 1] = tostring(message)
        end,
    }
    _G.ppu = {
        readbyte = function(address)
            ppu_reads = ppu_reads + 1
            return address % 256
        end,
    }
    _G.rom = nil
    _G.AND = nil
    _G.BIT = nil
    _G.DW_EMULATOR_COMPAT = nil
    _G.DW_BIZHAWK_NATIVE_API = nil

    return logs, joypad_state, input_state, joypad_sets, function()
        return ppu_reads
    end
end

local function setup_fceux()
    save_globals()
    package.loaded["emulator_compat"] = nil

    _G.FCEU = {
        frameadvance = function() end,
    }
    _G.emu = nil
    _G.memory = {}
    _G.mainmemory = nil
    _G.joypad = nil
    _G.input = nil
    _G.console = nil
    _G.ppu = nil
    _G.rom = nil
    _G.AND = nil
    _G.BIT = nil
    _G.DW_EMULATOR_COMPAT = nil
    _G.DW_BIZHAWK_NATIVE_API = nil
end

function tests.fceux_global_without_bizhawk_api_stays_fceux()
    setup_fceux()

    local compat = require "emulator_compat"

    assert_equal(compat.is_fceux, true, "FCEUX-only globals should detect FCEUX")
    assert_equal(compat.is_bizhawk, false, "FCEUX-only globals should not detect BizHawk")

    restore_globals()
end

function tests.bizhawk_reload_prefers_real_api_over_stale_fceux_shim()
    local logs = setup_bizhawk({
        ["System Bus"] = {
            [0x600C] = 4,
        },
    }, {"System Bus"})
    _G.FCEU = {
        frameadvance = function() end,
    }

    local compat = require "emulator_compat"

    assert_equal(compat.is_bizhawk, true, "BizHawk globals should win over stale FCEU shim after reload")
    assert_equal(compat.is_fceux, false, "stale FCEU shim should not disable BizHawk mode")
    assert_equal(memory.readbyte(0x600C), 4, "BizHawk memory shim should still be installed")
    assert_contains(table.concat(logs, "\n"), "cart RAM adapter using memory domain: System Bus", "BizHawk adapter should initialize normally")

    restore_globals()
end

function tests.bizhawk_reload_unwraps_stale_input_and_joypad_shims()
    local _, joypad_state, input_state, joypad_sets = setup_bizhawk({
        ["System Bus"] = {
            [0x600C] = 4,
        },
    }, {"System Bus"})
    joypad_state["P1 A"] = true
    input_state.X = true

    require "emulator_compat"
    assert_equal(joypad.read(1).A, true, "first load should read native BizHawk joypad input")
    assert_equal(input.get().X, true, "first load should read native BizHawk keyboard input")

    package.loaded["emulator_compat"] = nil
    require "emulator_compat"

    assert_equal(joypad.read(1).A, true, "reload should unwrap stale joypad shim back to native BizHawk input")
    assert_equal(input.get().X, true, "reload should unwrap stale input shim back to native BizHawk input")
    joypad.set(1, {A = true})
    assert_equal(joypad_sets[#joypad_sets].buttons.A, true, "reload joypad.set should send BizHawk A instead of neutralizing controls")

    restore_globals()
end

function tests.bizhawk_reload_replaces_frameadvance_wrapper_and_flushes_new_ppu_cache()
    local _, _, _, _, get_ppu_reads = setup_bizhawk({
        ["System Bus"] = {
            [0x600C] = 4,
        },
    }, {"System Bus"})

    require "emulator_compat"
    local first_frameadvance = FCEU.frameadvance

    package.loaded["emulator_compat"] = nil
    local compat = require "emulator_compat"

    assert_equal(FCEU.frameadvance == first_frameadvance, false, "BizHawk reload should replace the old frameadvance cache hook")
    ppu.readbyte(0x2000)
    ppu.readbyte(0x2000)
    assert_equal(get_ppu_reads(), 1, "within-frame PPU reads should still use the cache")
    FCEU.frameadvance()
    ppu.readbyte(0x2000)
    assert_equal(get_ppu_reads(), 2, "new frameadvance hook should flush the new PPU cache")
    assert_equal(compat.get_ppu_stats_snapshot().cache_flushes, 1, "new adapter should own cache flush accounting after reload")

    restore_globals()
end

function tests.mainmemory_read_failure_falls_back_to_system_bus()
    local logs = setup_bizhawk({
        ["System Bus"] = {
            [0x0045] = 0x05,
        },
    }, {"System Bus"})
    _G.mainmemory.read_u8 = function()
        error(69)
    end

    require "emulator_compat"

    assert_equal(memory.readbyte(0x0045), 0x05, "mainmemory read failure should fall back to System Bus domain")
    assert_contains(table.concat(logs, "\n"), "mainmemory.read_u8 failed", "fallback should log the native memory read failure")

    restore_globals()
end

function tests.console_log_failure_does_not_crash_memory_fallback()
    setup_bizhawk({
        ["System Bus"] = {
            [0x0045] = 0x08,
        },
    }, {"System Bus"})
    _G.console.log = function()
        error("console closed")
    end
    _G.mainmemory.read_u8 = function()
        error(69)
    end

    require "emulator_compat"

    assert_equal(memory.readbyte(0x0045), 0x08, "console logging failure should not crash fallback memory reads")

    restore_globals()
end

function tests.temporarily_unavailable_memory_read_returns_zero()
    setup_bizhawk({}, {"System Bus"})
    _G.mainmemory.read_u8 = nil
    _G.memory.read_u8 = nil
    _G.memory.readbyte = nil

    require "emulator_compat"

    assert_equal(memory.readbyte(0x0045), 0, "unavailable BizHawk memory reads should not crash the Lua loop")

    restore_globals()
end

function tests.temporarily_unavailable_memory_write_is_ignored()
    setup_bizhawk({}, {"System Bus"})
    _G.mainmemory.write_u8 = nil
    _G.memory.write_u8 = nil
    _G.memory.writebyte = nil

    require "emulator_compat"

    memory.writebyte(0x0045, 0x08)

    restore_globals()
end

function tests.ppu_source_probe_reads_direct_ppu_and_candidate_domains()
    setup_bizhawk({
        ["CIRAM"] = {
            [0x0000] = 0xAA,
            [0x0400] = 0xBB,
        },
    }, {"CIRAM"})

    local compat = require "emulator_compat"
    local sources = compat.get_ppu_source_rows({0})
    local direct = find_source(sources, "ppu.readbyte")
    local ciram = find_source(sources, "CIRAM")

    assert_equal(direct ~= nil, true, "PPU source probe should include native ppu.readbyte")
    assert_equal(ciram ~= nil, true, "PPU source probe should include mapped CIRAM domain")
    assert_equal(direct.rows[0].nt0[1], 0x00, "native PPU source should read direct PPU addresses")
    assert_equal(ciram.rows[0].nt0[1], 0xAA, "CIRAM source should map NT0 to nametable offset 0")
    assert_equal(ciram.rows[0].nt1[1], 0xBB, "CIRAM source should map NT1 to nametable offset 0x400")

    restore_globals()
end

function tests.ppu_adapter_prefers_nametable_domain_over_native_ppu()
    local logs = setup_bizhawk({
        ["CIRAM"] = {
            [0x0000] = 0xAA,
            [0x0400] = 0xBB,
        },
    }, {"CIRAM"})

    require "emulator_compat"

    assert_equal(ppu.readbyte(0x2000), 0xAA, "PPU adapter should prefer nametable domain NT0 bytes")
    assert_equal(ppu.readbyte(0x2400), 0xBB, "PPU adapter should prefer nametable domain NT1 bytes")
    assert_contains(table.concat(logs, "\n"), "PPU adapter using memory domain: CIRAM", "PPU adapter should log selected nametable domain")

    restore_globals()
end

function tests.ppu_adapter_bulk_range_uses_nametable_domain_and_cache()
    setup_bizhawk({
        ["CIRAM"] = {
            [0x0000] = 0xAA,
            [0x0001] = 0xAB,
            [0x0002] = 0xAC,
            [0x0003] = 0xAD,
        },
    }, {"CIRAM"})

    local compat = require "emulator_compat"
    local bytes = ppu.readbyterange(0x2000, 4)

    assert_equal(bytes[1], 0xAA, "bulk range byte 1 should come from CIRAM")
    assert_equal(bytes[4], 0xAD, "bulk range byte 4 should come from CIRAM")

    local stats = compat.get_ppu_stats_snapshot()
    assert_equal(stats.read_calls, 4, "bulk range should count logical PPU byte reads")
    assert_equal(stats.bulk_reads, 1, "bulk range should use one bulk memory API call")
    assert_equal(stats.bulk_bytes, 4, "bulk range should record bulk byte count")
    assert_equal(stats.cache_misses, 4, "first bulk range should populate cache")

    local cached = ppu.readbyterange(0x2000, 4)
    assert_equal(cached[2], 0xAB, "cached bulk range should return the same bytes")
    stats = compat.get_ppu_stats_snapshot()
    assert_equal(stats.read_calls, 8, "cached range should still count logical reads")
    assert_equal(stats.cache_hits, 4, "second range should hit the PPU cache")
    assert_equal(stats.bulk_reads, 1, "cached range should not issue another bulk API call")

    restore_globals()
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
