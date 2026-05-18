-- test_debug_tools.lua
-- Focused regression tests for debug_tools input-bridge behavior.

local original_preload = {}
local original_loaded = {}
local original_input = _G.input
local original_joypad = _G.joypad
local original_compat = _G.DW_EMULATOR_COMPAT

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
    local module_names = {
        "addresses",
        "config",
        "debug_tools",
        "map_reader",
        "maps",
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
                    return "ERROR"
                elseif key == "enable_keyboard_input_bridge" then
                    return "true"
                end
                return nil
            end,
        }
    end

    package.preload["addresses"] = function()
        return {}
    end

    package.preload["maps"] = function()
        return {}
    end

    package.preload["map_reader"] = function()
        return {}
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

    local bridge_path = "dw_keyboard_input.txt"
    local original_bridge = read_file(bridge_path)
    write_file(bridge_path, options.bridge_text or "-\n")

    local debug_tools = require "debug_tools"

    return {
        debug_tools = debug_tools,
        set_input = function(keys)
            input_state = keys or {}
        end,
        set_joy = function(buttons)
            joy_state = buttons or {}
        end,
        set_bridge = function(text)
            write_file(bridge_path, text or "-\n")
        end,
        restore = function()
            write_file(bridge_path, original_bridge or "")
            restore_modules(module_names)
            _G.input = original_input
            _G.joypad = original_joypad
            _G.DW_EMULATOR_COMPAT = original_compat
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

local tests = {}

function tests.fceux_stale_alt_neutral_bridge_is_ignored()
    local env = make_env({input_state = {LeftAlt = true}, bridge_text = "-\n"})

    local input = env.debug_tools.tick(1, "field")
    assert_equal(input, nil, "idle stale FCEUX Alt should not synthesize joypad input")

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

local count = 0
for name, fn in pairs(tests) do
    fn()
    count = count + 1
    print("PASS  " .. name)
end

print(string.format("Ran %d Lua unit tests", count))
