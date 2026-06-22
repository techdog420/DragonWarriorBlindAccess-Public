-- test_sweep_walk_command_surface.lua
-- Static command-surface checks for the movement-based sweep entry point.

local function read_file(path)
    local f = assert(io.open(path, "r"))
    local text = f:read("*a")
    f:close()
    return text
end

local function assert_contains(haystack, needle, message)
    if not string.find(haystack, needle, 1, true) then
        error(string.format("%s: missing %s", message, needle), 2)
    end
end

local function assert_not_contains(haystack, needle, message)
    if string.find(haystack, needle, 1, true) then
        error(string.format("%s: unexpected %s", message, needle), 2)
    end
end

local main = read_file("main.lua")
local debug_tools = read_file("debug_tools.lua")
local hooks = read_file("debug_hooks.txt")
local commands = read_file("dw_commands.sh")
local lower_status_guard = main:match("local function lower_status_noise_suppression_active%(%)(.-)\nend\n\nlocal function bizhawk_dialogue_hint")
assert(lower_status_guard, "main.lua should expose lower_status_noise_suppression_active before bizhawk_dialogue_hint")

assert_contains(main,
    'debug_tools.register_command("sweep_walk"',
    "main.lua should register the sweep_walk command")
assert_contains(main,
    "map_crawler.start_walk_sweep",
    "sweep_walk should use the map_crawler movement path")
assert_contains(main,
    'debug_tools.register_command("__stop_sweep"',
    "main.lua should hook legacy stop_sweep to stop movement-backed sweep_walk")
assert_contains(debug_tools,
    'custom_commands["__stop_sweep"]',
    "debug_tools stop_sweep should consult the movement-backed sweep hook before legacy sweep state")
assert_contains(main,
    'DW_QOL_STATE.perform_teleport_to(tx, ty, flag)',
    "teleport_to command should use normal speech behavior after the speech bridge hang fix")
assert_not_contains(main,
    'DW_QOL_STATE.perform_teleport_to(tx, ty, flag, {speak = false})',
    "teleport_to command should not keep the temporary speech-suppression probe")
assert_contains(main,
    "make_teleport_neutral_input",
    "teleport input suppression should use a compact neutral joypad table")
assert_contains(main,
    "if not extra then return {} end",
    "teleport neutral input should release controls with an empty table")
assert_contains(main,
    "joypad.set(1, make_teleport_neutral_input(extra))",
    "teleport input suppression should avoid all-false joypad tables")
assert_contains(main,
    "teleport_input_neutralized_frame",
    "teleport input suppression should record the frame already neutralized")
assert_contains(main,
    "DW_QOL_STATE.teleport_input_neutralized_frame ~= frame_count",
    "main loop should skip duplicate same-frame teleport neutralization")
assert_contains(main,
    'trace_teleport_loop("SKIP_NEUTRALIZE_ALREADY_DONE")',
    "teleport guard should log when same-frame neutralization is skipped")
assert_contains(main,
    "teleport_guard_active",
    "main loop should name the active teleport guard condition")
assert_contains(main,
    "emulator_compat.is_fceux and teleport_guard_active",
    "FCEUX should skip guard-frame joypad neutralization after teleport")
assert_contains(main,
    'trace_teleport_loop("SKIP_NEUTRALIZE_FCEUX_GUARD_ACTIVE")',
    "teleport guard should log when FCEUX guard-frame neutralization is skipped")
assert_contains(main,
    "TELEPORT_FRAMEADVANCE_%s",
    "teleport guard should log frameadvance boundaries while debugging stalls")
assert_contains(main,
    "TELEPORT_LOOP_%s",
    "teleport guard should log main-loop breadcrumbs before frameadvance")
assert_contains(main,
    'trace_teleport_loop("POST_DEBUG_TICK")',
    "teleport guard should log after debug_tools.tick returns")
assert_contains(main,
    'trace_teleport_loop("PRE_NEUTRALIZE")',
    "teleport guard should log before neutralizing teleport input")
assert_contains(main,
    'trace_teleport_loop("POST_NEUTRALIZE")',
    "teleport guard should log after neutralizing teleport input")
assert_contains(main,
    'trace_teleport_frameadvance("ENTER")',
    "teleport guard should log before frameadvance while debugging stalls")
assert_contains(main,
    'trace_teleport_frameadvance("RETURN")',
    "teleport guard should log after frameadvance returns while debugging stalls")
assert_contains(main,
    "map_crawler.is_active and map_crawler.is_active()",
    "can-walk diagnostics should also fire while map crawl/sweep_walk is active")
assert_contains(main,
    "map_crawl_active=%s",
    "can-walk diagnostics should identify active map crawl state")
assert_contains(main,
    "LOWER_DIALOGUE_ROW",
    "dialogue diagnostics should expose wrapped lower-reader rows")
assert_contains(main,
    "text.is_passive_field_status_noise(dialogue)",
    "check_dialogue should absorb passive status/name artifacts before stabilizing lower dialogue")
assert_contains(main,
    "lower_status_noise_suppression_active",
    "check_dialogue should use a named guard for status/name lower-window artifacts")
assert_contains(main,
    "map_crawler.is_active and map_crawler.is_active()",
    "status/name lower-window artifact suppression should apply during sweep_walk map crawl movement")
assert_contains(lower_status_guard,
    "auto_step.is_route_active and auto_step.is_route_active()",
    "status/name lower-window artifact suppression should apply during auto-walk and door verifier routes")
assert_contains(debug_tools,
    "TELEPORT_TICK_%s",
    "debug_tools.tick should log teleport breadcrumbs around command polling")
assert_contains(debug_tools,
    'trace_teleport_tick("POST_COMMANDS")',
    "debug_tools.tick should log after command polling")
assert_contains(debug_tools,
    'trace_teleport_tick("PRE_RETURN")',
    "debug_tools.tick should log before returning simulated input")
assert_contains(hooks,
    "sweep_walk",
    "debug_hooks.txt should document the sweep_walk command")
assert_contains(commands,
    "sweep_walk",
    "dw_commands.sh should list the sweep_walk command")

print("test_sweep_walk_command_surface.lua: command surface checks passed")
