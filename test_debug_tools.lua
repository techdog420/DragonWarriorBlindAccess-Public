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
local original_keyboard_bridge_override = _G.DW_KEYBOARD_BRIDGE_FILE_OVERRIDE
local env_counter = 0

local function join_path(dir, name)
    local last = dir:sub(-1)
    if last == "/" or last == "\\" then
        return dir .. name
    end
    local sep = (dir:match("^%a:") or dir:find("\\", 1, true)) and "\\" or "/"
    return dir .. sep .. name
end

local function temp_path(name)
    local dir = os.getenv("DW_TEST_TMPDIR")
        or os.getenv("TMPDIR")
        or os.getenv("TEMP")
        or os.getenv("TMP")
        or "."
    return join_path(dir, name)
end

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
    local command_file = temp_path("test_debug_tools_dw_commands_" .. tostring(env_counter) .. ".txt")
    local processing_file = temp_path("test_debug_tools_dw_commands_" .. tostring(env_counter) .. ".processing.txt")
    local module_names = {
        "addresses",
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
                if options.config_values and options.config_values[key] ~= nil then
                    return options.config_values[key]
                end
                if key == "debug_mode" then
                    return "true"
                elseif key == "debug_log_level" then
                    return options.log_level or "ERROR"
                elseif key == "enable_keyboard_input_bridge" then
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
            BUTTONS_PRESSED = 0x0047,
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
    _G.DW_DEBUG_LOG_FILE_OVERRIDE = options.log_file or temp_path("test_debug_tools_dw_debug.log")
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
    local memory_writes = {}
    local memory_write_hooks = {}
    _G.memory = {
        readbyte = function(address)
            return memory_bytes[address] or 0
        end,
        writebyte = function(address, value)
            memory_writes[#memory_writes + 1] = {address = address, value = value}
            memory_bytes[address] = value
            if memory_write_hooks[address] then
                memory_write_hooks[address](address, 1, value)
            end
        end,
        registerwrite = function(address, size_or_fn, maybe_fn)
            local fn = maybe_fn
            if type(size_or_fn) == "function" or size_or_fn == nil then
                fn = size_or_fn
            end
            memory_write_hooks[address] = fn
        end,
    }
    if options.register_values then
        _G.memory.getregister = function(name)
            return options.register_values[name]
        end
    elseif options.register_error then
        _G.memory.getregister = function(name)
            error(options.register_error)
        end
    end

    local bridge_path = temp_path("test_debug_tools_keyboard_bridge_" .. tostring(env_counter) .. ".txt")
    local original_bridge = read_file(bridge_path)
    _G.DW_KEYBOARD_BRIDGE_FILE_OVERRIDE = bridge_path
    if options.bridge_missing then
        os.remove(bridge_path)
    else
        write_file(bridge_path, options.bridge_text or "-\n")
    end

    local debug_tools = require "debug_tools"

    return {
        debug_tools = debug_tools,
        log_file = _G.DW_DEBUG_LOG_FILE_OVERRIDE,
        command_file = command_file,
        memory_writes = memory_writes,
        memory_write_hooks = memory_write_hooks,
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
        remove_bridge = function()
            os.remove(bridge_path)
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
            if original_bridge ~= nil then
                write_file(bridge_path, original_bridge)
            else
                os.remove(bridge_path)
            end
            restore_modules(module_names)
            _G.input = original_input
            _G.joypad = original_joypad
            _G.memory = original_memory
            _G.AND = original_and
            _G.DW_EMULATOR_COMPAT = original_compat
            _G.DW_DEBUG_LOG_FILE_OVERRIDE = original_log_override
            _G.DW_COMMAND_FILE_OVERRIDE = original_command_override
            _G.DW_COMMAND_PROCESSING_FILE_OVERRIDE = original_command_processing_override
            _G.DW_KEYBOARD_BRIDGE_FILE_OVERRIDE = original_keyboard_bridge_override
        end,
    }
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or "assert_equal failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assert_contains(text, needle, message)
    if not tostring(text or ""):find(tostring(needle or ""), 1, true) then
        error((message or "assert_contains failed") .. ": expected to find " .. tostring(needle) .. " in " .. tostring(text), 2)
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

function tests.fceux_stale_alt_return_is_ignored_with_neutral_external_bridge()
    local env = make_env({input_state = {LeftAlt = true, Return = true}, bridge_text = "-\n"})

    local input = env.debug_tools.tick(1, "field")
    assert_equal(input, nil, "latched FCEUX Alt+Return should not synthesize repeated Start")

    env.restore()
end

function tests.fceux_neutral_external_bridge_blocks_stale_alt_f_fallback()
    local env = make_env({input_state = {LeftAlt = true, F = true}, bridge_text = "-\n"})

    local input = env.debug_tools.tick(1, "field")
    assert_equal(input, nil, "neutral sidecar state should override stale FCEUX Alt+F")

    env.restore()
end

function tests.fceux_missing_external_bridge_blocks_stale_alt_f_fallback()
    local env = make_env({input_state = {LeftAlt = true, F = true}, bridge_missing = true})

    local input = env.debug_tools.tick(1, "field")
    assert_equal(input, nil, "missing sidecar should fail closed instead of mapping stale FCEUX Alt+F")

    env.restore()
end

function tests.fceux_missing_external_bridge_releases_active_input_once()
    local env = make_env({
        input_state = {},
        bridge_text = string.format("v2:1:%d:A\n", os.time()),
    })

    local press = env.debug_tools.tick(1, "field")
    assert_equal(press ~= nil and press.A == true, true, "live sidecar should press A")

    env.remove_bridge()
    local release = env.debug_tools.tick(2, "field")
    assert_equal(release ~= nil and release._raw == true, true, "missing sidecar should release active input once")
    assert_no_buttons(release)

    local missing = env.debug_tools.tick(3, "field")
    assert_equal(missing, nil, "continued missing sidecar should remain fail-closed")

    env.restore()
end

function tests.fceux_external_bridge_direction_is_not_marked_as_neutral_stale()
    local env = make_env({input_state = {LeftAlt = true}, bridge_text = string.format("v2:1:%d:up\n", os.time())})

    local input = env.debug_tools.tick(1, "field")
    assert_equal(input ~= nil, true, "bridged FCEUX direction should return raw input")
    assert_equal(input._raw, true, "bridged FCEUX direction should be raw")
    assert_equal(input.up, true, "external bridge direction should pass through")
    assert_equal(input._stale_fceux_keyboard, nil, "real bridge direction should not be treated as a neutral stale frame")

    env.restore()
end

function tests.fceux_external_bridge_release_with_stale_alt_emits_neutral_raw_frame()
    local env = make_env({input_state = {LeftAlt = true}, bridge_text = string.format("v2:1:%d:A\n", os.time())})

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
    local env = make_env({input_state = {LeftAlt = true}, bridge_text = string.format("v2:1:%d:start\n", os.time())})

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

function tests.fceux_suspended_bridge_blocks_alt_f_internal_fallback()
    local env = make_env({input_state = {LeftAlt = true, F = true}, bridge_text = "suspended\n"})

    local input = env.debug_tools.tick(1, "field")
    assert_equal(input, nil, "menu-suspended bridge should block the internal stale-Alt F-to-A fallback")

    env.restore()
end

function tests.fceux_suspended_bridge_releases_active_input_once()
    local env = make_env({input_state = {}, bridge_text = string.format("v2:1:%d:A\n", os.time())})

    local press = env.debug_tools.tick(1, "field")
    assert_equal(press ~= nil and press.A == true, true, "active external bridge should press A")

    env.set_input({LeftAlt = true, F = true})
    env.set_bridge("suspended\n")
    local release = env.debug_tools.tick(2, "field")
    assert_equal(release ~= nil and release._raw == true, true, "suspension should release active bridge input once")
    assert_no_buttons(release)

    local held_suspend = env.debug_tools.tick(3, "field")
    assert_equal(held_suspend, nil, "continued menu suspension should not repeat neutral joypad.set frames")

    env.restore()
end

function tests.fceux_legacy_active_bridge_fails_closed_immediately()
    local env = make_env({input_state = {LeftAlt = true, F = true}, bridge_text = "A\n"})

    local input = env.debug_tools.tick(1, "field")
    assert_equal(input, nil, "unleased legacy active state should not inject A")

    env.restore()
end

function tests.fceux_stale_sidecar_heartbeat_releases_each_input_class()
    local cases = {
        {line = "A", button = "A"},
        {line = "start", button = "start"},
        {line = "left", button = "left"},
    }

    for _, case in ipairs(cases) do
        local now = os.time()
        local env = make_env({
            input_state = {},
            bridge_text = string.format("v2:10:%d:%s\n", now, case.line),
        })

        local press = env.debug_tools.tick(1, "field")
        assert_equal(press ~= nil and press[case.button] == true, true,
            "live heartbeat should carry active " .. case.line)

        env.set_bridge(string.format("v2:10:%d:%s\n", now - 10, case.line))
        local release = env.debug_tools.tick(2, "field")
        assert_equal(release ~= nil and release._raw == true, true,
            "expired heartbeat should release " .. case.line)
        assert_no_buttons(release)

        local expired = env.debug_tools.tick(3, "field")
        assert_equal(expired, nil,
            "expired " .. case.line .. " should stay fail-closed without repeated neutral frames")

        env.set_bridge(string.format("v2:11:%d:%s\n", os.time(), case.line))
        local recovered = env.debug_tools.tick(4, "field")
        assert_equal(recovered ~= nil and recovered[case.button] == true, true,
            "fresh heartbeat should restore " .. case.line)

        env.restore()
    end
end

function tests.fceux_bridge_remains_active_when_debug_mode_is_false()
    local env = make_env({
        input_state = {},
        bridge_text = string.format("v2:1:%d:up\n", os.time()),
        config_values = {debug_mode = "false"},
    })

    local input = env.debug_tools.tick(1, "field")
    assert_equal(input ~= nil and input._raw == true, true, "release mode should still consume raw bridge input")
    assert_equal(input.up, true, "release mode bridge should preserve keyboard movement")

    env.restore()
end

function tests.edge_probe_input_guard_refuses_game_button_contamination()
    local env = make_env({
        input_state = {LeftAlt = true},
        joy_state = {},
        bridge_text = "-\n",
        memory_bytes = {[0x0047] = 0x20},
    })

    local refusal = env.debug_tools.edge_probe_input_refusal("probe_edge")
    env.restore()

    assert_equal(refusal ~= nil, true, "guard should refuse when game buttons stay set while Lua input is idle")
    assert_contains(refusal, "probe_edge refused: input contaminated", "refusal should name contaminated input")
    assert_contains(refusal, "keys=LeftAlt", "refusal should include stale Alt evidence")
    assert_contains(refusal, "joy=-", "refusal should include idle joy evidence")
    assert_contains(refusal, "bridge=-", "refusal should include neutral bridge evidence")
    assert_contains(refusal, "buttons=0x20", "refusal should include game-side button byte")
end

function tests.input_guard_captures_and_clears_stuck_game_button_byte()
    local env = make_env({
        log_level = "INFO",
        input_state = {LeftAlt = true},
        joy_state = {},
        bridge_text = "-\n",
        memory_bytes = base_snapshot_ram({[0x0047] = 0x20}),
    })

    local refusal = env.debug_tools.input_contamination_refusal("survey_objects")
    local neutral = env.debug_tools.tick(1, "field")
    env.debug_tools.tick(8, "field")
    env.debug_tools.tick(30, "field")

    local log = read_file(env.log_file) or ""
    local writes = env.memory_writes
    env.restore()

    assert_equal(refusal ~= nil, true, "contaminated input should still refuse the caller")
    assert_equal(neutral ~= nil and neutral._raw == true, true, "contamination guard should emit raw neutral input")
    assert_no_buttons(neutral)
    assert_equal(#writes, 1, "contamination guard should clear exactly the game input byte")
    assert_equal(writes[1].address, 0x0047, "auto-clear should target BUTTONS_PRESSED")
    assert_equal(writes[1].value, 0x00, "auto-clear should zero BUTTONS_PRESSED")
    assert_contains(log, "INPUT_CONTAMINATION_CAPTURE command=survey_objects", "guard should capture the pre-clear state")
    assert_contains(log, "GAME_INPUT_AUTO_CLEAR command=survey_objects before=0x20 after=0x00 addr=0x0047", "guard should log the immediate clear result")
    assert_contains(log, "GAME_INPUT_AUTO_CLEAR_CHECK command=survey_objects buttons=0x00 frames=8", "guard should log the delayed post-clear state")
end

function tests.input_guard_allows_timing_suspect_route_blocked_self_direction()
    local env = make_env({
        log_level = "INFO",
        input_state = {LeftAlt = true},
        joy_state = {},
        bridge_text = "-\n",
        memory_bytes = base_snapshot_ram({[0x0047] = 0x20}),
    })

    local refusal = env.debug_tools.input_contamination_refusal("survey_objects", {
        allow_route_blocked_self_input = true,
        route_blocked_timing_suspect = true,
        route_blocked_dir = "down",
        route_blocked_source = "queued_route",
    })
    env.debug_tools.flush()

    local log = read_file(env.log_file) or ""
    local writes = env.memory_writes
    env.restore()

    assert_equal(refusal, nil, "self-injected timing-suspect direction should not be refused")
    assert_equal(#writes, 0, "allowed self-injected direction should not be auto-cleared by the guard")
    assert_contains(log,
        "INPUT_CONTAMINATION_IGNORED command=survey_objects reason=route_blocked_self_input dir=down buttons=0x20 source=queued_route",
        "guard should log the precise self-input allowance")
end

function tests.edge_probe_input_guard_allows_benign_stale_alt_idle()
    local env = make_env({
        input_state = {LeftAlt = true},
        joy_state = {},
        bridge_text = "-\n",
        memory_bytes = {[0x0047] = 0x00},
    })

    local refusal = env.debug_tools.edge_probe_input_refusal("probe_edge")
    env.restore()

    assert_equal(refusal, nil, "stale Alt alone should remain benign for probes")
end

function tests.edge_probe_input_guard_allows_active_bridge_input()
    local env = make_env({
        input_state = {LeftAlt = true},
        joy_state = {},
        bridge_text = string.format("v2:1:%d:up\n", os.time()),
        memory_bytes = {[0x0047] = 0x20},
    })

    local refusal = env.debug_tools.edge_probe_input_refusal("probe_edge")
    env.restore()

    assert_equal(refusal, nil, "real bridge input should not be classified as idle contamination")
end

function tests.edge_probe_input_guard_rejects_expired_bridge_input()
    local env = make_env({
        input_state = {LeftAlt = true},
        joy_state = {},
        bridge_text = string.format("v2:1:%d:up\n", os.time() - 10),
        memory_bytes = {[0x0047] = 0x20},
    })

    local refusal = env.debug_tools.edge_probe_input_refusal("probe_edge")
    local writes = env.memory_writes
    env.restore()

    assert_equal(refusal ~= nil, true, "expired bridge direction should not excuse contaminated game input")
    assert_equal(#writes, 1, "expired bridge contamination should clear the game input byte")
    assert_equal(writes[1].address, 0x0047, "expired bridge cleanup should target BUTTONS_PRESSED")
    assert_equal(writes[1].value, 0x00, "expired bridge cleanup should neutralize BUTTONS_PRESSED")
end

function tests.clear_game_input_byte_zeroes_buttons_pressed_and_logs_result()
    local env = make_env({
        log_level = "INFO",
        memory_bytes = {[0x0047] = 0x20},
    })

    env.write_command_file("clear_game_input\n")
    env.debug_tools.tick(60, "field")

    local log = read_file(env.log_file) or ""
    local writes = env.memory_writes
    env.restore()

    assert_equal(#writes, 1, "clear_game_input should write exactly one byte")
    assert_equal(writes[1].address, 0x0047, "clear_game_input should target BUTTONS_PRESSED")
    assert_equal(writes[1].value, 0x00, "clear_game_input should zero BUTTONS_PRESSED")
    assert_contains(log, "GAME_INPUT_CLEAR before=0x20 after=0x00", "clear result should be logged")
end

function tests.input_bridge_runtime_off_suppresses_internal_and_external_bridge()
    local env = make_env({
        log_level = "INFO",
        input_state = {LeftAlt = true, Up = true},
        bridge_text = string.format("v2:1:%d:A\n", os.time()),
    })

    env.write_command_file("set_input_bridge:off\n")
    local off_input = env.debug_tools.tick(60, "field")
    local still_off = env.debug_tools.tick(61, "field")

    env.set_bridge(string.format("v2:2:%d:A\n", os.time()))
    env.write_command_file("set_input_bridge:config\n")
    local restored = env.debug_tools.tick(120, "field")

    local log = read_file(env.log_file) or ""
    env.restore()

    assert_equal(off_input ~= nil and off_input._raw == true, true, "turning bridge off should emit a raw neutral release frame")
    assert_no_buttons(off_input)
    assert_equal(still_off, nil, "runtime bridge off should suppress later bridge input")
    assert_equal(restored ~= nil, true, "clearing override should restore config-driven bridge behavior")
    assert_equal(restored._raw, true, "restored bridge input should remain raw")
    assert_equal(restored.A, true, "external bridge input should be restored after config mode")
    assert_contains(log, "INPUT_BRIDGE_OVERRIDE state=off", "bridge override should log off state")
    assert_contains(log, "INPUT_BRIDGE_OVERRIDE state=config", "bridge override should log config reset")
end

function tests.input_isolation_command_clears_input_and_emits_neutral_raw_frames()
    local hook_calls = {}
    local env = make_env({
        log_level = "INFO",
        input_state = {LeftAlt = true},
        bridge_text = string.format("v2:1:%d:up\n", os.time()),
        memory_bytes = base_snapshot_ram({[0x0047] = 0x80}),
    })
    env.debug_tools.register_command("__input_isolation", function(details)
        hook_calls[#hook_calls + 1] = details
    end)

    env.write_command_file("isolate_input:3\n")
    local first = env.debug_tools.tick(60, "field")
    local second = env.debug_tools.tick(61, "field")
    local third = env.debug_tools.tick(62, "field")
    env.set_bridge(string.format("v2:2:%d:up\n", os.time()))
    local restored = env.debug_tools.tick(63, "field")
    env.debug_tools.flush()

    local log = read_file(env.log_file) or ""
    local writes = env.memory_writes
    env.restore()

    assert_equal(#hook_calls, 1, "input isolation should notify the runtime cleanup hook")
    assert_equal(hook_calls[1].frames, 3, "cleanup hook should receive the isolation duration")
    assert_equal(#writes >= 1, true, "input isolation should clear game-side input")
    assert_equal(writes[1].address, 0x0047, "input isolation should target BUTTONS_PRESSED")
    assert_equal(writes[1].value, 0x00, "input isolation should zero BUTTONS_PRESSED")
    assert_equal(first ~= nil and first._raw == true, true, "first isolation frame should emit raw neutral input")
    assert_no_buttons(first)
    assert_equal(second ~= nil and second._raw == true, true, "second isolation frame should stay raw neutral")
    assert_no_buttons(second)
    assert_equal(third ~= nil and third._raw == true, true, "third isolation frame should stay raw neutral")
    assert_no_buttons(third)
    assert_equal(restored ~= nil and restored.up == true, true, "bridge should resume after the isolation window expires")
    assert_contains(log, "INPUT_ISOLATION_START frames=3", "isolation start should be logged")
    assert_contains(log, "INPUT_ISOLATION_END", "isolation end should be logged")
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
    local env = make_env({input_state = {LeftAlt = true}, bridge_text = string.format("v2:1:%d:up\n", os.time()), tolk_outputs = spoken})

    for frame = 1, 180 do
        env.debug_tools.tick(frame, "field")
    end
    assert_equal(#spoken, 0, "bridged controls should not trigger idle stuck-Alt speech")

    env.restore()
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

function tests.report_cpu_state_logs_registers_and_game_context()
    local env = make_env({
        log_level = "INFO",
        register_values = {
            pc = 0xC626,
            a = 0x41,
            x = 0x02,
            y = 0x03,
            s = 0xFD,
            p = 0x24,
        },
        memory_bytes = base_snapshot_ram({
            [0x003A] = 25,
            [0x003B] = 23,
            [0x003C] = 0x08,
            [0x003D] = 0x08,
            [0x0045] = 0x0A,
            [0x0047] = 0x20,
            [0xC626] = 0xAD,
            [0xC627] = 0x16,
            [0xC628] = 0x40,
        }),
    })

    env.write_command_file("report_cpu_state:wedged\n")
    env.debug_tools.tick(60, "field")

    local log = read_file(env.log_file) or ""
    env.restore()

    assert_contains(log, "CPU_STATE tag=wedged", "CPU report should run with the supplied tag")
    assert_contains(log, "pc=0xC626 a=0x41 x=0x02 y=0x03 s=0xFD p=0x24", "CPU report should include registers")
    assert_contains(log, "op=C626:AD 16 40", "CPU report should include opcode bytes at PC")
    assert_contains(log, "map=0x0A(Test Map)", "CPU report should include current map")
    assert_contains(log, "player=(25,23)", "CPU report should include current player position")
    assert_contains(log, "buttons=0x20 move=0x08 sub=0x08", "CPU report should include stuck input/movement bytes")
end

function tests.report_cpu_state_logs_unavailable_when_register_api_missing()
    local env = make_env({
        log_level = "INFO",
        memory_bytes = base_snapshot_ram({
            [0x003A] = 25,
            [0x003B] = 23,
            [0x0045] = 0x0A,
            [0x0047] = 0x00,
        }),
    })

    env.write_command_file("report_cpu_state:missing_api\n")
    env.debug_tools.tick(60, "field")

    local log = read_file(env.log_file) or ""
    env.restore()

    assert_contains(log, "CPU_STATE_UNAVAILABLE tag=missing_api reason=memory.getregister_unavailable", "missing API should be logged")
    assert_contains(log, "map=0x0A(Test Map)", "unavailable report should still include current map")
    assert_contains(log, "player=(25,23)", "unavailable report should still include current player position")
end

function tests.report_oam_offset_flags_misaligned_sprite_clear_offset()
    local env = make_env({
        log_level = "INFO",
        register_values = {
            pc = 0xB9ED,
            y = 0x2A,
        },
        memory_bytes = base_snapshot_ram({
            [0x004E] = 0x2A,
            [0x004F] = 0x81,
            [0xB9ED] = 0xC0,
            [0xB9EE] = 0x00,
            [0xB9EF] = 0xF0,
        }),
    })

    env.write_command_file("report_oam_offset:wedged\n")
    env.debug_tools.tick(60, "field")

    local log = read_file(env.log_file) or ""
    env.restore()

    assert_contains(log, "OAM_OFFSET tag=wedged", "OAM report should run with the supplied tag")
    assert_contains(log, "addr=0x004E value=0x2A aligned=false", "misaligned offset should be explicit")
    assert_contains(log, "reaches_zero=false iterations_to_zero=never", "bad offset should be diagnosed as non-terminating")
    assert_contains(log, "pc=0xB9ED y=0x2A op=B9ED:C0 00 F0", "report should include CPU context")
    assert_contains(log, "diagnosis=misaligned_offset_will_never_exit_B9ED_B9F8", "report should name the hard-lock loop")
end

function tests.watch_oam_offset_verbose_logs_writer_value_and_cpu_context()
    local env = make_env({
        log_level = "INFO",
        register_values = {
            pc = 0xB812,
            y = 0x2A,
        },
        memory_bytes = base_snapshot_ram({
            [0x004F] = 0x81,
            [0xB812] = 0x84,
            [0xB813] = 0x4E,
            [0xB814] = 0xA9,
        }),
    })

    env.write_command_file("watch_oam_offset_verbose:repro\n")
    env.debug_tools.tick(60, "field")
    _G.memory.writebyte(0x004E, 0x2A)
    env.debug_tools.flush()

    local log = read_file(env.log_file) or ""
    env.restore()

    assert_contains(log, "OAM_OFFSET_WATCH_ARMED tag=repro addr=0x004E mode=verbose", "verbose watch should arm on demand")
    assert_contains(log, "OAM_OFFSET_WRITE tag=repro addr=0x004E value=0x2A aligned=false", "watch should log the bad write")
    assert_contains(log, "pc=0xB812 y=0x2A op=B812:84 4E A9", "watch should include writer CPU context")
end

function tests.watch_oam_offset_quiet_logs_stuck_loop_with_recent_writes()
    local regs = {
        pc = 0xB812,
        y = 0x2A,
    }
    local env = make_env({
        log_level = "INFO",
        register_values = regs,
        memory_bytes = base_snapshot_ram({
            [0x004F] = 0x81,
            [0xB812] = 0x84,
            [0xB813] = 0x4E,
            [0xB814] = 0xA9,
            [0xB9ED] = 0xC0,
            [0xB9EE] = 0x00,
            [0xB9EF] = 0xF0,
        }),
    })

    env.write_command_file("watch_oam_offset:repro\n")
    env.debug_tools.tick(60, "field")
    _G.memory.writebyte(0x004E, 0x2A)
    regs.pc = 0xB9ED
    env.debug_tools.tick(61, "field")
    env.debug_tools.tick(62, "field")
    env.debug_tools.flush()

    local log = read_file(env.log_file) or ""
    env.restore()

    assert_contains(log, "OAM_OFFSET_WATCH_ARMED tag=repro addr=0x004E mode=quiet", "quiet watch should arm on demand")
    assert_equal(log:find("OAM_OFFSET_WRITE tag=repro", 1, true), nil, "quiet watch should not log every write")
    assert_contains(log, "OAM_OFFSET_STUCK tag=repro", "quiet watch should log when the bad loop is reached")
    assert_contains(log, "value=0x2A aligned=false", "stuck report should include bad value")
    assert_contains(log, "pc=0xB9ED y=0x2A op=B9ED:C0 00 F0", "stuck report should include loop CPU context")
    assert_contains(log, "recent={frame=60 pc=0xB812 value=0x2A", "stuck report should include recent writer context")
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
local filter = os.getenv("DW_TEST_FILTER")
for name, fn in pairs(tests) do
    if not filter or name:find(filter, 1, true) then
        fn()
        count = count + 1
        print("PASS  " .. name)
    end
end

print(string.format("Ran %d Lua unit tests", count))
