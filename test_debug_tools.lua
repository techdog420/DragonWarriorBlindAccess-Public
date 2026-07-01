-- test_debug_tools.lua
-- Focused regression tests for debug_tools input-bridge behavior.

local original_preload = {}
local original_loaded = {}
local original_input = _G.input
local original_joypad = _G.joypad
local original_memory = _G.memory
local original_and = _G.AND
local original_compat = _G.DW_EMULATOR_COMPAT
local original_log_override = _G.DW_DEBUG_LOG_FILE_OVERRIDE
local original_command_override = _G.DW_COMMAND_FILE_OVERRIDE
local original_command_processing_override = _G.DW_COMMAND_PROCESSING_FILE_OVERRIDE
local original_bridge_hotkey_override = _G.DW_BRIDGE_HOTKEY_FILE_OVERRIDE
local env_counter = 0

local function save_module(name)
    original_preload[name] = package.preload[name]
    original_loaded[name] = package.loaded[name]
end

local function restore_modules(names)
    for _, name in ipairs(names) do
        package.preload[name] = original_preload[name]
        package.loaded[name] = original_loaded[name]
    end
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local text = f:read("*a")
    f:close()
    return text
end

local function write_file(path, text)
    local f = assert(io.open(path, "w"))
    f:write(text or "")
    f:close()
end

local function make_env(options)
    options = options or {}
    local input_state = options.input_state or {}
    local joy_state = options.joy_state or {}
    env_counter = env_counter + 1
    local command_file = "/tmp/test_debug_tools_dw_commands_" .. tostring(env_counter) .. ".txt"
    local processing_file = "/tmp/test_debug_tools_dw_commands_" .. tostring(env_counter) .. ".processing.txt"
    local module_names = {
        "addresses",
        "bridge_hotkeys",
        "config",
        "debug_tools",
        "map_reader",
        "maps",
        "route_manager",
        "tolk",
    }

    for _, name in ipairs(module_names) do
        save_module(name)
        package.loaded[name] = nil
    end

    package.preload["config"] = function()
        return {
            get = function(key)
                if key == "debug_mode" then
                    return "true"
                elseif key == "debug_log_level" then
                    return options.log_level or "ERROR"
                elseif key == "enable_keyboard_input_bridge" then
                    return "true"
                elseif key == "enable_fceux_bridge_hotkeys" then
                    return "true"
                end
                return nil
            end,
        }
    end

    package.preload["addresses"] = function()
        return {
            MAP_ID = 0x0045,
            PLAYER_X = 0x003A,
            PLAYER_Y = 0x003B,
            OVERWORLD_X = 0x0042,
            OVERWORLD_Y = 0x003E,
            TERRAIN_OFFSET = 0x0016,
            EXPERIENCE_LO = 0x00BA,
            EXPERIENCE_HI = 0x00BB,
            GOLD_LO = 0x00BC,
            GOLD_HI = 0x00BD,
            KEYS = 0x00BF,
            HERBS = 0x00C0,
            CURRENT_HP = 0x00C5,
            CURRENT_MP = 0x00C6,
            LEVEL = 0x00C7,
            STRENGTH = 0x00C8,
            AGILITY = 0x00C9,
            MAX_HP = 0x00CA,
            MAX_MP = 0x00CB,
            ATTACK = 0x00CC,
            DEFENSE = 0x00CD,
            SPELLS = 0x00CE,
            FLAGS_CF = 0x00CF,
            MENU_CURSOR_X = 0x00D8,
            MENU_CURSOR_Y = 0x00D9,
            COMBAT_FLAGS = 0x00DF,
            ENEMY_HP = 0x00E2,
            QUEST_FLAGS = 0x00E4,
            NPC_COUNT = 20,
            NPC_DATA_START = 0x0051,
            NPC_ENTRY_SIZE = 3,
        }
    end

    package.preload["maps"] = function()
        return {
            get_name = function(map_id)
                if map_id == 0x09 then
                    return "Garinham"
                end
                return "Test Map"
            end,
            is_overworld = function()
                return options.overworld == true
            end,
        }
    end

    package.preload["map_reader"] = function()
        return {
            get_map_dimensions = function()
                return 10, 10
            end,
            get_tile_type = function()
                return 1
            end,
            is_walkable = function()
                return true
            end,
        }
    end

    package.preload["route_manager"] = function()
        return {
            freeze_npcs = function() end,
            unfreeze_npcs = function() end,
        }
    end

    local tolk_outputs = options.tolk_outputs
    package.preload["tolk"] = function()
        return {
            output = function(text)
                if tolk_outputs then
                    tolk_outputs[#tolk_outputs + 1] = text
                end
            end,
        }
    end

    _G.DW_EMULATOR_COMPAT = {is_fceux = true, is_bizhawk = false}
    _G.DW_DEBUG_LOG_FILE_OVERRIDE = options.log_file or "/tmp/test_debug_tools_dw_debug.log"
    _G.DW_COMMAND_FILE_OVERRIDE = command_file
    _G.DW_COMMAND_PROCESSING_FILE_OVERRIDE = processing_file
    _G.input = {
        get = function()
            return input_state
        end,
    }
    _G.joypad = {
        read = function()
            return joy_state
        end,
    }
    _G.AND = function(a, b)
        local result = 0
        local bit = 1
        a = tonumber(a) or 0
        b = tonumber(b) or 0
        while a > 0 and b > 0 do
            if (a % 2 == 1) and (b % 2 == 1) then
                result = result + bit
            end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            bit = bit * 2
        end
        return result
    end
    local memory_bytes = options.memory_bytes or {}
    _G.memory = {
        readbyte = function(address)
            return memory_bytes[address] or 0
        end,
    }

    local bridge_path = "dw_keyboard_input.txt"
    local original_bridge = read_file(bridge_path)
    write_file(bridge_path, options.bridge_text or "-\n")
    local bridge_hotkey_path = "/tmp/test_debug_tools_bridge_hotkeys_" .. tostring(env_counter) .. ".txt"
    write_file(bridge_hotkey_path, options.bridge_hotkey_text or "-\n")
    _G.DW_BRIDGE_HOTKEY_FILE_OVERRIDE = bridge_hotkey_path

    local debug_tools = require "debug_tools"

    return {
        debug_tools = debug_tools,
        log_file = _G.DW_DEBUG_LOG_FILE_OVERRIDE,
        command_file = command_file,
        write_command_file = function(text)
            write_file(command_file, text or "")
        end,
        set_input = function(keys)
            input_state = keys or {}
        end,
        set_joy = function(buttons)
            joy_state = buttons or {}
        end,
        set_bridge = function(text)
            write_file(bridge_path, text or "-\n")
        end,
        set_bridge_hotkeys = function(text)
            write_file(bridge_hotkey_path, text or "-\n")
        end,
        set_memory = function(address, value)
            memory_bytes[address] = value
        end,
        set_memory_bytes = function(overrides)
            for address, value in pairs(overrides or {}) do
                memory_bytes[address] = value
            end
        end,
        restore = function()
            os.remove(command_file)
            os.remove(processing_file)
            os.remove(bridge_hotkey_path)
            write_file(bridge_path, original_bridge or "")
            restore_modules(module_names)
            _G.input = original_input
            _G.joypad = original_joypad
            _G.memory = original_memory
            _G.AND = original_and
            _G.DW_EMULATOR_COMPAT = original_compat
            _G.DW_DEBUG_LOG_FILE_OVERRIDE = original_log_override
            _G.DW_COMMAND_FILE_OVERRIDE = original_command_override
            _G.DW_COMMAND_PROCESSING_FILE_OVERRIDE = original_command_processing_override
            _G.DW_BRIDGE_HOTKEY_FILE_OVERRIDE = original_bridge_hotkey_override
        end,
    }
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or "assert_equal failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assert_no_buttons(input)
    assert_equal(input.up, false, "neutral bridge should not press up")
    assert_equal(input.down, false, "neutral bridge should not press down")
    assert_equal(input.left, false, "neutral bridge should not press left")
    assert_equal(input.right, false, "neutral bridge should not press right")
    assert_equal(input.A, false, "neutral bridge should not press A")
    assert_equal(input.B, false, "neutral bridge should not press B")
    assert_equal(input.start, false, "neutral bridge should not press start")
    assert_equal(input.select, false, "neutral bridge should not press select")
end

local function base_snapshot_ram(overrides)
    local ram = {
        [0x0016] = 0x20,
        [0x003A] = 11,
        [0x003B] = 2,
        [0x003E] = 4,
        [0x0042] = 19,
        [0x0045] = 0x19,
        [0x00BA] = 0x53,
        [0x00BB] = 0x10,
        [0x00BC] = 0xD0,
        [0x00BD] = 0x0B,
        [0x00BE] = 0xB5,
        [0x00BF] = 3,
        [0x00C0] = 2,
        [0x00C1] = 0x45,
        [0x00C2] = 0xC3,
        [0x00C3] = 0x00,
        [0x00C4] = 0x00,
        [0x00C5] = 0x3F,
        [0x00C6] = 0x34,
        [0x00C7] = 12,
        [0x00C8] = 0x30,
        [0x00C9] = 0x24,
        [0x00CA] = 0x3F,
        [0x00CB] = 0x34,
        [0x00CC] = 0x44,
        [0x00CD] = 0x30,
        [0x00CE] = 0x3F,
        [0x00CF] = 0x10,
        [0x00D8] = 0,
        [0x00D9] = 0,
        [0x00DF] = 0x08,
        [0x00E2] = 0,
        [0x00E4] = 0,
    }
    for address, value in pairs(overrides or {}) do
        ram[address] = value
    end
    return ram
end

local tests = {}

function tests.fceux_stale_alt_neutral_bridge_is_ignored()
    local env = make_env({input_state = {LeftAlt = true}, bridge_text = "-\n"})

    local input = env.debug_tools.tick(1, "field")
    assert_equal(input, nil, "idle stale FCEUX Alt should not synthesize joypad input")

    env.restore()
end

function tests.fceux_stale_alt_return_is_ignored_without_external_bridge()
    local env = make_env({input_state = {LeftAlt = true, Return = true}, bridge_text = "-\n"})

    local input = env.debug_tools.tick(1, "field")
    assert_equal(input, nil, "latched FCEUX Alt+Return should not synthesize repeated Start")

    env.restore()
end

function tests.fceux_external_bridge_direction_is_not_marked_as_neutral_stale()
    local env = make_env({input_state = {LeftAlt = true}, bridge_text = "up\n"})

    local input = env.debug_tools.tick(1, "field")
    assert_equal(input ~= nil, true, "bridged FCEUX direction should return raw input")
    assert_equal(input._raw, true, "bridged FCEUX direction should be raw")
    assert_equal(input.up, true, "external bridge direction should pass through")
    assert_equal(input._stale_fceux_keyboard, nil, "real bridge direction should not be treated as a neutral stale frame")

    env.restore()
end

function tests.fceux_external_bridge_release_with_stale_alt_emits_neutral_raw_frame()
    local env = make_env({input_state = {LeftAlt = true}, bridge_text = "A\n"})

    local press = env.debug_tools.tick(1, "field")
    assert_equal(press ~= nil, true, "bridge press should emit raw input")
    assert_equal(press._raw, true, "bridge press should be raw")
    assert_equal(press.A, true, "bridge press should include A")

    env.set_bridge("-\n")
    local release = env.debug_tools.tick(2, "field")
    assert_equal(release ~= nil, true, "bridge release should emit one neutral frame")
    assert_equal(release._raw, true, "bridge release should be raw so auto_step ignores it")
    assert_no_buttons(release)

    local idle = env.debug_tools.tick(3, "field")
    assert_equal(idle, nil, "bridge release should only emit one neutral frame")

    env.restore()
end

function tests.fceux_external_bridge_release_after_focus_recovery_emits_neutral_raw_frame()
    local env = make_env({input_state = {LeftAlt = true}, bridge_text = "start\n"})

    local press = env.debug_tools.tick(1, "field")
    assert_equal(press ~= nil, true, "bridge start press should emit raw input")
    assert_equal(press._raw, true, "bridge start press should be raw")
    assert_equal(press.start, true, "bridge press should include start")

    env.set_input({})
    env.set_bridge("-\n")
    local release = env.debug_tools.tick(2, "field")
    assert_equal(release ~= nil, true, "focus-recovery bridge clear should emit one neutral frame")
    assert_equal(release._raw, true, "focus-recovery bridge release should be raw")
    assert_no_buttons(release)

    local idle = env.debug_tools.tick(3, "field")
    assert_equal(idle, nil, "focus-recovery bridge release should only emit one neutral frame")

    env.restore()
end

function tests.fceux_idle_input_without_stale_alt_has_no_bridge_input()
    local env = make_env({input_state = {}, bridge_text = "-\n"})

    local input = env.debug_tools.tick(1, "field")
    assert_equal(input, nil, "idle FCEUX input should not synthesize bridge input")

    env.restore()
end

function tests.fceux_stale_alt_warning_is_log_only()
    local spoken = {}
    local env = make_env({input_state = {LeftAlt = true}, bridge_text = "-\n", tolk_outputs = spoken})

    for frame = 1, 120 do
        env.debug_tools.tick(frame, "field")
    end
    assert_equal(#spoken, 0, "idle stale-Alt should not speak when treated as benign")

    env.set_input({})
    env.debug_tools.tick(121, "field")
    env.set_input({LeftAlt = true})
    for frame = 122, 241 do
        env.debug_tools.tick(frame, "field")
    end
    assert_equal(#spoken, 0, "repeated idle stale-Alt should stay log-only")

    env.restore()
end

function tests.fceux_stale_alt_with_real_bridge_input_does_not_warn()
    local spoken = {}
    local env = make_env({input_state = {LeftAlt = true}, bridge_text = "up\n", tolk_outputs = spoken})

    for frame = 1, 180 do
        env.debug_tools.tick(frame, "field")
    end
    assert_equal(#spoken, 0, "bridged controls should not trigger idle stuck-Alt speech")

    env.restore()
end

function tests.input_status_includes_mod_bridge_state()
    local env = make_env({
        log_level = "INFO",
        bridge_hotkey_text = "Bridge2\n",
    })

    env.write_command_file("input_status:bridge_probe\n")
    env.debug_tools.tick(60, "field")

    local log = read_file(env.log_file) or ""
    env.restore()

    assert_equal(
        log:find("INPUT_STATUS tag=bridge_probe", 1, true) ~= nil,
        true,
        "input_status should run with the supplied tag"
    )
    assert_equal(
        log:find("mod_bridge=Bridge2", 1, true) ~= nil,
        true,
        "input_status should include the bridge hotkey state"
    )
end

function tests.trace_input_includes_mod_bridge_state_changes()
    local env = make_env({
        log_level = "INFO",
        bridge_hotkey_text = "-\n",
    })

    env.write_command_file("trace_input:3\n")
    env.debug_tools.tick(60, "field")
    env.debug_tools.tick(61, "field")
    env.set_bridge_hotkeys("Bridge3\n")
    env.debug_tools.tick(62, "field")
    env.debug_tools.flush()

    local log = read_file(env.log_file) or ""
    env.restore()

    assert_equal(
        log:find("INPUT_TRACE", 1, true) ~= nil,
        true,
        "trace_input should log samples"
    )
    assert_equal(
        log:find("mod_bridge=-", 1, true) ~= nil,
        true,
        "trace_input should log neutral bridge hotkey state"
    )
    assert_equal(
        log:find("mod_bridge=Bridge3", 1, true) ~= nil,
        true,
        "trace_input should log bridge hotkey state changes"
    )
end

function tests.raw_sequence_release_frame_stays_raw()
    local env = make_env({input_state = {}, bridge_text = "-\n"})

    env.write_command_file("simulate_raw_sequence:RIGHT,2,0\n")

    local first = env.debug_tools.tick(60, "field")
    assert_equal(first ~= nil, true, "raw sequence should emit first frame")
    assert_equal(first._raw, true, "raw sequence first frame should be raw")
    assert_equal(first.right, true, "raw sequence should press right")

    local second = env.debug_tools.tick(61, "field")
    assert_equal(second ~= nil, true, "raw sequence should emit second frame")
    assert_equal(second._raw, true, "raw sequence second frame should be raw")
    assert_equal(second.right, true, "raw sequence should keep pressing right")

    local release = env.debug_tools.tick(62, "field")
    assert_equal(release ~= nil, true, "raw sequence should emit a neutral release frame")
    assert_equal(release._raw, true, "raw sequence release should stay raw so auto_step ignores it")
    assert_no_buttons(release)

    local idle = env.debug_tools.tick(63, "field")
    assert_equal(idle, nil, "raw sequence should be done after the raw release frame")

    env.restore()
end

function tests.legacy_sweep_stop_reports_unsafe_untrusted_output()
    local env = make_env({log_level = "INFO"})

    env.write_command_file("sweep_map\n")
    env.debug_tools.tick(60, "field")

    env.write_command_file("stop_sweep\n")
    env.debug_tools.tick(120, "field")
    env.debug_tools.tick(150, "field")

    local log = read_file(env.log_file) or ""
    env.restore()

    assert_equal(
        log:find("SWEEP_LEGACY_UNSAFE command=sweep_map trusted=false teleport_used=true", 1, true) ~= nil,
        true,
        "legacy sweep should announce that teleport-backed output is untrusted"
    )
    assert_equal(
        log:find("SWEEP_LEGACY_UNSAFE persist_skipped=true trusted=false", 1, true) ~= nil,
        true,
        "legacy sweep stop should skip trusted persistence"
    )
end

function tests.report_movement_state_includes_player_sprite_position_bytes()
    local env = make_env({
        log_level = "INFO",
        memory_bytes = base_snapshot_ram({
            [0x003A] = 4,
            [0x003B] = 7,
            [0x0090] = 0x40,
            [0x0091] = 0x00,
            [0x0092] = 0x70,
            [0x0093] = 0x00,
        }),
    })

    env.write_command_file("report_movement_state:teleport_probe\n")
    env.debug_tools.tick(60, "field")

    local log = read_file(env.log_file) or ""
    env.restore()

    assert_equal(
        log:find("MOVEMENT_STATE tag=teleport_probe", 1, true) ~= nil,
        true,
        "movement-state report should run with the supplied tag"
    )
    assert_equal(
        log:find("ram0090_0093=40 00 70 00", 1, true) ~= nil,
        true,
        "movement-state report should include player sprite-position bytes"
    )
end

function tests.flush_writes_buffered_debug_log_immediately()
    local env = make_env({log_level = "INFO", memory_bytes = base_snapshot_ram()})

    env.debug_tools.info("FLUSH_TEST_MARKER")
    assert_equal(
        (read_file(env.log_file) or ""):find("FLUSH_TEST_MARKER", 1, true) ~= nil,
        false,
        "log marker should remain buffered before explicit flush"
    )

    env.debug_tools.flush()

    local log = read_file(env.log_file) or ""
    env.restore()

    assert_equal(
        log:find("FLUSH_TEST_MARKER", 1, true) ~= nil,
        true,
        "explicit flush should write buffered debug log entries"
    )
end

function tests.snapshot_logs_raw_player_stat_block()
    local ram = {
        [0x0016] = 0x10,
        [0x003A] = 15,
        [0x003B] = 15,
        [0x003E] = 48,
        [0x0042] = 56,
        [0x0045] = 0x09,
        [0x00BA] = 0x73,
        [0x00BB] = 0x10,
        [0x00BC] = 0x0B,
        [0x00BD] = 0x0C,
        [0x00BF] = 3,
        [0x00C0] = 1,
        [0x00C5] = 15,
        [0x00C6] = 0,
        [0x00C7] = 12,
        [0x00C8] = 0x12,
        [0x00C9] = 0x25,
        [0x00CA] = 15,
        [0x00CB] = 0,
        [0x00CC] = 0x60,
        [0x00CD] = 0x61,
        [0x00CE] = 0,
        [0x00CF] = 0x10,
        [0x00D8] = 0,
        [0x00D9] = 1,
        [0x00DF] = 0x08,
        [0x00E2] = 14,
        [0x00E4] = 0,
    }
    local env = make_env({log_level = "INFO", memory_bytes = ram})

    env.debug_tools.tick(1, "field")
    env.debug_tools.snapshot()
    env.debug_tools.tick(30, "field")

    local log = read_file(env.log_file) or ""
    env.restore()

    assert_equal(
        log:find("stats:     STR=0x12 AGI=0x25 ATK=0x60 DEF=0x61", 1, true) ~= nil,
        true,
        "snapshot should log raw derived combat stat bytes"
    )
    assert_equal(
        log:find("stat_ram:  BA-CF=73 10 0B 0C 00 03 01 00 00 00 00 0F 00 0C 12 25 0F 00 60 61 00 10", 1, true) ~= nil,
        true,
        "snapshot should log contiguous player stat RAM for corruption forensics"
    )
end

function tests.stat_integrity_allows_level_one_without_spells()
    local ram = base_snapshot_ram({
        [0x00C5] = 15,
        [0x00C6] = 0,
        [0x00C7] = 1,
        [0x00C8] = 4,
        [0x00C9] = 3,
        [0x00CA] = 15,
        [0x00CB] = 0,
        [0x00CC] = 4,
        [0x00CD] = 3,
        [0x00CE] = 0,
        [0x00CF] = 0,
    })
    local env = make_env({log_level = "INFO", memory_bytes = ram})

    env.debug_tools.tick(1, "battle")
    env.debug_tools.check_player_stat_integrity("level_one_battle")
    env.debug_tools.tick(30, "battle")

    local log = read_file(env.log_file) or ""
    env.restore()

    assert_equal(
        log:find("PLAYER_STAT_INTEGRITY_WARNING", 1, true),
        nil,
        "level 1 with no spells/max MP should not be flagged"
    )
end

function tests.stat_integrity_warns_on_level_twelve_spell_and_stat_collapse()
    local ram = base_snapshot_ram({
        [0x00C5] = 15,
        [0x00C6] = 0,
        [0x00C7] = 12,
        [0x00C8] = 4,
        [0x00C9] = 3,
        [0x00CA] = 15,
        [0x00CB] = 0,
        [0x00CC] = 0x18,
        [0x00CD] = 0x1F,
        [0x00CE] = 0,
        [0x00CF] = 0x10,
    })
    local env = make_env({log_level = "INFO", memory_bytes = ram})

    env.debug_tools.tick(1, "field")
    env.debug_tools.check_player_stat_integrity("post_battle")
    env.debug_tools.tick(30, "field")

    local log = read_file(env.log_file) or ""
    env.restore()

    assert_equal(
        log:find("PLAYER_STAT_INTEGRITY_WARNING context=post_battle", 1, true) ~= nil,
        true,
        "corrupt high-level stat block should be flagged"
    )
    assert_equal(
        log:find("missing_spells_for_level", 1, true) ~= nil,
        true,
        "warning should explain missing high-level spells"
    )
    assert_equal(
        log:find("stat_ram=53 10 D0 0B B5 03 02 45 C3 00 00 0F 00 0C 04 03 0F 00 18 1F 00 10", 1, true) ~= nil,
        true,
        "warning should include the raw stat RAM block"
    )
end

function tests.battle_start_trace_dumps_recent_stat_history_for_corruption()
    local env = make_env({log_level = "INFO", memory_bytes = base_snapshot_ram()})

    env.debug_tools.tick(1, "field")
    env.debug_tools.tick(2, "field")
    env.set_memory_bytes({
        [0x003A] = 13,
        [0x003B] = 10,
        [0x00BA] = 0xC9,
        [0x00BB] = 0x10,
        [0x00BC] = 0xF1,
        [0x00BD] = 0x0C,
        [0x00C5] = 0x38,
        [0x00C6] = 0x2A,
        [0x00C8] = 0x04,
        [0x00C9] = 0x03,
        [0x00CA] = 0x0F,
        [0x00CB] = 0x00,
        [0x00CC] = 0x18,
        [0x00CD] = 0x1F,
        [0x00CE] = 0x00,
        [0x00E2] = 241,
    })

    env.debug_tools.on_battle_start()
    env.debug_tools.tick(30, "battle")

    local log = read_file(env.log_file) or ""
    env.restore()

    assert_equal(
        log:find("PLAYER_STAT_TRACE_BEGIN context=battle_start", 1, true) ~= nil,
        true,
        "battle-start corruption should dump the recent trace"
    )
    assert_equal(
        log:find("origin=history frame=1", 1, true) ~= nil,
        true,
        "trace should include recent healthy history"
    )
    assert_equal(
        log:find("origin=current frame=2", 1, true) ~= nil,
        true,
        "trace should include the current suspicious sample"
    )
    assert_equal(
        log:find("changed=BA,BC,BD,C5,C6,C8,C9,CA,CB,CC,CD,CE", 1, true) ~= nil,
        true,
        "trace should highlight the exact stat bytes that flipped"
    )
end

function tests.stat_integrity_transition_dumps_clean_to_corrupt_history()
    local env = make_env({log_level = "INFO", memory_bytes = base_snapshot_ram()})

    env.debug_tools.tick(1, "field")
    env.set_memory_bytes({
        [0x003A] = 13,
        [0x003B] = 10,
        [0x00C5] = 0x34,
        [0x00C6] = 0x1E,
        [0x00C8] = 0x04,
        [0x00C9] = 0x03,
        [0x00CA] = 0x0F,
        [0x00CB] = 0x00,
        [0x00CC] = 0x18,
        [0x00CD] = 0x1F,
        [0x00CE] = 0x00,
    })
    env.debug_tools.tick(2, "field")
    env.debug_tools.tick(30, "field")

    local log = read_file(env.log_file) or ""
    env.restore()

    assert_equal(
        log:find("PLAYER_STAT_INTEGRITY_TRANSITION from=clean to=bad", 1, true) ~= nil,
        true,
        "first clean-to-corrupt frame should be logged"
    )
    assert_equal(
        log:find("PLAYER_STAT_TRACE_BEGIN context=stat_transition", 1, true) ~= nil,
        true,
        "transition should dump recent stat history"
    )
    assert_equal(
        log:find("origin=history frame=1", 1, true) ~= nil,
        true,
        "transition trace should include the previous clean frame"
    )
    assert_equal(
        log:find("origin=current frame=2", 1, true) ~= nil,
        true,
        "transition trace should include the first corrupt frame"
    )
    assert_equal(
        log:find("changed=C5,C6,C8,C9,CA,CB,CC,CD,CE", 1, true) ~= nil,
        true,
        "transition trace should highlight the player-stat bytes that flipped"
    )
end

function tests.frameadvance_boundary_logs_clean_to_corrupt_stat_transition()
    local env = make_env({log_level = "INFO", memory_bytes = base_snapshot_ram()})

    env.debug_tools.tick(51249, "field")
    env.debug_tools.before_frameadvance()
    env.set_memory_bytes({
        [0x00C8] = 0x04,
        [0x00C9] = 0x03,
        [0x00CA] = 0x0F,
        [0x00CB] = 0x00,
        [0x00CC] = 0x18,
        [0x00CD] = 0x1F,
        [0x00CE] = 0x00,
    })
    env.debug_tools.after_frameadvance()
    env.debug_tools.tick(51250, "field")
    env.debug_tools.tick(51270, "field")

    local log = read_file(env.log_file) or ""
    env.restore()

    assert_equal(
        log:find("PLAYER_STAT_FRAMEADVANCE_TRANSITION from=clean to=bad pre_frame=51249 post_frame=51250 state=field", 1, true) ~= nil,
        true,
        "frameadvance boundary should log clean-to-corrupt stat transitions"
    )
    assert_equal(
        log:find("changed=C8,C9,CA,CB,CC,CD,CE", 1, true) ~= nil,
        true,
        "frameadvance boundary should list changed stat bytes"
    )
    assert_equal(
        log:find("before_stat_ram=53 10 D0 0B B5 03 02 45 C3 00 00 3F 34 0C 30 24 3F 34 44 30 3F 10", 1, true) ~= nil,
        true,
        "frameadvance boundary should include the clean pre-frame stat block"
    )
    assert_equal(
        log:find("after_stat_ram=53 10 D0 0B B5 03 02 45 C3 00 00 3F 34 0C 04 03 0F 00 18 1F 00 10", 1, true) ~= nil,
        true,
        "frameadvance boundary should include the corrupt post-frame stat block"
    )
end

function tests.battle_start_skips_duplicate_trace_after_recent_transition_dump()
    local env = make_env({log_level = "INFO", memory_bytes = base_snapshot_ram()})

    env.debug_tools.tick(1, "field")
    env.set_memory_bytes({
        [0x00C5] = 0x34,
        [0x00C6] = 0x1E,
        [0x00C8] = 0x04,
        [0x00C9] = 0x03,
        [0x00CA] = 0x0F,
        [0x00CB] = 0x00,
        [0x00CC] = 0x18,
        [0x00CD] = 0x1F,
        [0x00CE] = 0x00,
    })
    env.debug_tools.tick(2, "field")
    env.debug_tools.on_battle_start()
    env.debug_tools.tick(30, "battle")

    local log = read_file(env.log_file) or ""
    env.restore()

    assert_equal(
        log:find("PLAYER_STAT_TRACE_SKIPPED context=battle_start reason=recent_transition_dump", 1, true) ~= nil,
        true,
        "battle start should avoid dumping a duplicate trace right after the transition trace"
    )
end

local count = 0
for name, fn in pairs(tests) do
    fn()
    count = count + 1
    print("PASS  " .. name)
end

print(string.format("Ran %d Lua unit tests", count))
