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

local function assert_order(haystack, first, second, message)
    local first_pos = string.find(haystack, first, 1, true)
    local second_pos = string.find(haystack, second, 1, true)
    if not first_pos or not second_pos or first_pos >= second_pos then
        error(string.format("%s: expected %s before %s", message, first, second), 2)
    end
end

local main = read_file("main.lua")
local debug_tools = read_file("debug_tools.lua")
local hooks = read_file("debug_hooks.txt")
local commands = read_file("dw_commands.sh")
local lower_status_guard = main:match("local function lower_status_noise_suppression_active%(%)(.-)\nend\n\nlocal function bizhawk_dialogue_hint")
assert(lower_status_guard, "main.lua should expose lower_status_noise_suppression_active before bizhawk_dialogue_hint")
local y1_dialogue_reader = main:match("local function read_y1_dialogue%(dialogue_fallback%)(.-)\nend\n\n%-%- strip_noise")
assert(y1_dialogue_reader, "main.lua should expose read_y1_dialogue before strip_noise")
local command_menu_handler = main:match("local function check_command_menu%(frame_delta%)(.-)\nend\n\n%-%- check_yesno_prompt")
assert(command_menu_handler, "main.lua should expose check_command_menu before check_yesno_prompt")
local command_menu_field_guard = main:match("DW_QOL_STATE%.command_menu_blocks_field_movement = function%(%)(.-)\nend\n\nDW_QOL_STATE%.arm_talk_visit_marker")
assert(command_menu_field_guard, "main.lua should expose command_menu_blocks_field_movement before arm_talk_visit_marker")
local dialogue_handler = main:match("local function check_dialogue%(frame_delta, refresh_ppu%)(.-)\nend\n\n%-%- check_upper_dialogue")
assert(dialogue_handler, "main.lua should expose check_dialogue before check_upper_dialogue")
local merchant_handler = main:match("local function check_merchant_screen%(frame_delta%)(.-)\nend\n\nlocal function check_battle_menu")
assert(merchant_handler, "main.lua should expose check_merchant_screen before check_battle_menu")
local navigation_refresh = main:match("local function refresh_navigation_modules%(%)(.-)\nend\n\nlocal function ensure_navigation_modules_fresh")
assert(navigation_refresh, "main.lua should expose refresh_navigation_modules before ensure_navigation_modules_fresh")
local route_manager = read_file("route_manager.lua")
local route_manager_refresh = route_manager:match("local function refresh_navigation_modules%(%)(.-)\nend\n\n%-%- Explicit manual/diagnostic hook")
assert(route_manager_refresh, "route_manager.lua should expose refresh_navigation_modules before its public hook")

assert_contains(main,
    'debug_tools.register_command("sweep_walk"',
    "main.lua should register the sweep_walk command")
assert_contains(navigation_refresh,
    'package.loaded["overworld_routes"] = nil',
    "navigation module reload should refresh overworld route tables")
assert_contains(navigation_refresh,
    'package.loaded["object_commands"] = nil',
    "navigation module reload should refresh command closures that capture overworld routes")
assert_contains(navigation_refresh,
    'overworld_routes = require "overworld_routes"',
    "navigation module reload should refresh main.lua's overworld route reference")
assert_contains(navigation_refresh,
    "object_command_module.register()",
    "navigation module reload should re-register object commands after refreshing route tables")
assert_contains(route_manager_refresh,
    'package.loaded["overworld_routes"] = nil',
    "route_manager navigation reload should refresh its overworld route module reference")
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
    "TELEPORT_INPUT_SKIP_NEUTRALIZE_FCEUX",
    "FCEUX teleport input suppression should not immediately call neutral joypad.set")
assert_contains(main,
    'trace_teleport_loop("SKIP_NEUTRALIZE_FCEUX_GUARD_ACTIVE")',
    "teleport guard should log when FCEUX guard-frame neutralization is skipped")
assert_contains(command_menu_field_guard,
    "menu.is_open()",
    "field movement guard should consult raw command-menu visibility")
assert_contains(command_menu_field_guard,
    "has_visible_cursor_tile()",
    "field movement guard should require a visible cursor before blocking an unconfirmed command menu")
assert_contains(command_menu_field_guard,
    "CMD.menu_live",
    "field movement guard should keep the confirmed-session branch for stale COMMAND text")
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
    'debug_tools.register_command("report_input_guard_state"',
    "main.lua should expose a read-only input guard diagnostic command")
assert_contains(main,
    "INPUT_GUARD_STATE",
    "input guard diagnostic should log a structured INPUT_GUARD_STATE line")
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
    'debug_tools.register_command("door_verify_after"',
    "main.lua should accept door_verify_after as a compatibility alias")
assert_contains(main,
    "map_crawl_active=%s",
    "can-walk diagnostics should identify active map crawl state")
assert_contains(main,
    "LOWER_DIALOGUE_ROW",
    "dialogue diagnostics should expose wrapped lower-reader rows")
assert_contains(main,
    "text.is_passive_field_status_noise(dialogue)",
    "check_dialogue should absorb passive status/name artifacts before stabilizing lower dialogue")
assert_contains(y1_dialogue_reader,
    "text.is_passive_field_status_noise(cleaned)",
    "row-1 dialogue reader should not let status/name fragments reset dialogue stability")
assert_contains(main,
    "lower_status_noise_suppression_active",
    "check_dialogue should use a named guard for status/name lower-window artifacts")
assert_not_contains(lower_status_guard,
    "DW_QOL_STATE.command_menu_blocks_field_movement()",
    "status/name lower-window artifact suppression should also apply while the field command menu is open")
assert_contains(lower_status_guard,
    'submenu_mode ~= nil and submenu_mode ~= "SPELL"',
    "status/name lower-window artifact suppression should still respect non-spell submenus")
assert_contains(lower_status_guard,
    "return true",
    "status/name lower-window artifact suppression should apply whenever field UI is otherwise clear")
assert_not_contains(lower_status_guard,
    "return map_crawler.is_active and map_crawler.is_active()",
    "status/name lower-window artifact suppression should not be limited to map crawl movement")
assert_contains(command_menu_handler,
    "text.is_passive_field_status_noise(lower_dialogue)",
    "command-menu lower-dialogue gate should ignore passive status/name fragments such as split hero-name suffixes")
assert_contains(main,
    "local function submenu_absorbs_lower_dialogue(dialogue)",
    "submenu lower-dialogue absorption should be centralized so SPELL results can be distinguished from spell-list rows")
assert_contains(main,
    'if submenu_mode == "STATUS" then',
    "STATUS submenu visual rows should still be absorbed as memory-spoken UI")
assert_contains(main,
    'if submenu_mode == "ITEM" then',
    "ITEM submenu dialogue ownership should be handled separately from STATUS")
assert_contains(command_menu_handler,
    'trace_row1("CMD_ITEM_USE"',
    "ITEM submenu should hand result dialogue off on the semantic item-use action rather than cursor visibility")
assert_contains(main,
    'if submenu_mode == "SPELL" then',
    "SPELL submenu absorption should be handled separately from STATUS/ITEM")
assert_contains(main,
    'return not tostring(dialogue or ""):find("[a-z]")',
    "SPELL submenu should absorb uppercase spell-list rows but allow lowercase result dialogue")
assert_contains(dialogue_handler,
    "if submenu_absorbs_lower_dialogue(dialogue) then",
    "lower dialogue reader should allow lowercase field spell-result dialogue through instead of marking it announced during SPELL mode")
assert_contains(command_menu_handler,
    "CMD.item_entry_pending_name",
    "ITEM submenu entry should remember the first spoken item so a delayed cursor jump cannot repeat it")
assert_contains(command_menu_handler,
    "if pending_name and current_item == pending_name then",
    "ITEM submenu cursor handling should suppress the delayed first-item duplicate by name, not only by short frame timing")
assert_contains(merchant_handler,
    'PREV.merchant_mode == "offers" and PREV.merchant_selection ~= nil',
    "merchant offer-list summary should stay quiet after an item selection is already known")
assert_order(merchant_handler,
    'debug_tools.info("MERCHANT_SELECT: " .. msg)',
    'PREV.merchant_mode == "offers" and PREV.merchant_selection ~= nil',
    "merchant summary suppression should run after changed cursor selections have a chance to speak")
assert_order(command_menu_handler,
    'trace_row1("CMD_ITEM_FIRE"',
    "local merchant_present = MER.active or MER.scan_present",
    "confirmed ITEM submenu entry should win before merchant false positives can own the held-item list")
assert_order(command_menu_handler,
    "local joy_a_now = joypad.read(1).A or false",
    "local merchant_present = MER.active or MER.scan_present",
    "A-button edge tracking should happen before merchant override so direct ITEM selection can claim ownership")
assert_order(command_menu_handler,
    "live_x == 1 and live_y == 1",
    "local merchant_present = MER.active or MER.scan_present",
    "direct ITEM selection from the command menu should win before merchant false positives can own the held-item list")
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
