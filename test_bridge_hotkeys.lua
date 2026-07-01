-- test_bridge_hotkeys.lua
-- Regression tests for the FCEUX bridge mod-hotkey state file.

local original_preload = {}
local original_loaded = {}
local original_override = _G.DW_BRIDGE_HOTKEY_FILE_OVERRIDE

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

local function write_file(path, text)
    local f = assert(io.open(path, "w"))
    f:write(text or "")
    f:close()
end

local function make_env(options)
    options = options or {}
    local module_names = {
        "bridge_hotkeys",
        "config",
        "emulator_compat",
    }

    for _, name in ipairs(module_names) do
        save_module(name)
        package.loaded[name] = nil
    end

    local path = "/tmp/test_bridge_hotkeys_" .. tostring(options.id or math.random(1000000)) .. ".txt"
    if options.initial_text ~= false then
        write_file(path, options.initial_text or "-\n")
    else
        os.remove(path)
    end
    _G.DW_BRIDGE_HOTKEY_FILE_OVERRIDE = path

    package.preload["config"] = function()
        return {
            get = function(key)
                if key == "enable_fceux_bridge_hotkeys" then
                    return options.enabled == false and "false" or "true"
                end
                return nil
            end,
        }
    end

    package.preload["emulator_compat"] = function()
        return {
            is_fceux = options.is_fceux ~= false,
            is_bizhawk = options.is_bizhawk == true,
        }
    end

    local bridge_hotkeys = require "bridge_hotkeys"

    return {
        bridge_hotkeys = bridge_hotkeys,
        path = path,
        set_bridge = function(text)
            write_file(path, text)
        end,
        restore = function()
            os.remove(path)
            _G.DW_BRIDGE_HOTKEY_FILE_OVERRIDE = original_override
            restore_modules(module_names)
        end,
    }
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local tests = {}

function tests.merge_keys_adds_valid_bridge_aliases()
    local env = make_env({initial_text = "Bridge2,Bridge8\n"})

    local keys = {K = true}
    local merged = env.bridge_hotkeys.merge_keys(keys)

    assert_equal(merged, keys, "merge_keys should update the passed key table")
    assert_equal(merged.K, true, "merge_keys should preserve existing keys")
    assert_equal(merged.Bridge2, true, "Bridge2 should be synthesized")
    assert_equal(merged.Bridge8, true, "Bridge8 should be synthesized")

    env.restore()
end

function tests.neutral_or_missing_file_does_not_change_keys()
    local neutral = make_env({initial_text = "-\n"})
    local keys = {K = true}

    neutral.bridge_hotkeys.merge_keys(keys)
    assert_equal(keys.Bridge1, nil, "neutral bridge state should not add aliases")
    neutral.restore()

    local missing = make_env({initial_text = false})
    local missing_keys = {}
    missing.bridge_hotkeys.merge_keys(missing_keys)
    assert_equal(missing_keys.Bridge1, nil, "missing bridge state file should not add aliases")
    assert_equal(missing.bridge_hotkeys.read_state_line(), "(missing)", "missing state should be visible in diagnostics")
    missing.restore()
end

function tests.disabled_or_non_fceux_bridge_does_not_synthesize_keys()
    local disabled = make_env({enabled = false, initial_text = "Bridge2\n"})
    local disabled_keys = {}
    disabled.bridge_hotkeys.merge_keys(disabled_keys)
    assert_equal(disabled_keys.Bridge2, nil, "disabled bridge should not add aliases")
    disabled.restore()

    local bizhawk = make_env({is_fceux = false, is_bizhawk = true, initial_text = "Bridge2\n"})
    local bizhawk_keys = {}
    bizhawk.bridge_hotkeys.merge_keys(bizhawk_keys)
    assert_equal(bizhawk_keys.Bridge2, nil, "BizHawk path should not add FCEUX bridge aliases")
    bizhawk.restore()
end

function tests.parser_rejects_non_bridge_aliases()
    local env = make_env({initial_text = "Bridge1,Shift,Bridge13,Bridge12,Enter\n"})

    local keys = {}
    env.bridge_hotkeys.merge_keys(keys)

    assert_equal(keys.Bridge1, true, "Bridge1 should be accepted")
    assert_equal(keys.Bridge12, true, "Bridge12 should be accepted")
    assert_equal(keys.Shift, nil, "ordinary key names should not be accepted from the bridge file")
    assert_equal(keys.Bridge13, nil, "out-of-range bridge aliases should not be accepted")
    assert_equal(keys.Enter, nil, "special key names should not be accepted from the bridge file")

    env.restore()
end

function tests.read_state_line_reports_current_raw_state()
    local env = make_env({initial_text = "Bridge3\n"})

    assert_equal(env.bridge_hotkeys.read_state_line(), "Bridge3", "diagnostics should report the raw bridge line")

    env.set_bridge("Bridge4\n")
    assert_equal(env.bridge_hotkeys.read_state_line(), "Bridge4", "diagnostics should pick up bridge file changes")

    env.restore()
end

local total = 0
for name, fn in pairs(tests) do
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        io.write("PASS  " .. name .. "\n")
    else
        io.stderr:write("FAIL  " .. name .. ": " .. tostring(err) .. "\n")
        os.exit(1)
    end
end

io.write(string.format("Ran %d Lua unit tests\n", total))
