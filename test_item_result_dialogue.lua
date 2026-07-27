-- Regression checks for field ITEM result dialogue ownership.

local function read_file(path)
    local f = assert(io.open(path, "r"))
    local contents = f:read("*a")
    f:close()
    return contents
end

local function assert_contains(haystack, needle, message)
    if not string.find(haystack, needle, 1, true) then
        error(string.format("%s: missing %s", message, needle), 2)
    end
end

local main = read_file("main.lua")
local guard_source = main:match(
    "(local function submenu_absorbs_lower_dialogue%(dialogue%).-\nend)\n\nlocal function check_dialogue")
assert(guard_source, "main.lua should expose submenu_absorbs_lower_dialogue before check_dialogue")

assert_contains(guard_source,
    'if submenu_mode == "STATUS" then',
    "STATUS rows should remain owned by the submenu reader")
assert_contains(guard_source,
    'if submenu_mode == "ITEM" then',
    "ITEM dialogue ownership should be handled separately from STATUS")
assert_contains(guard_source,
    "return true",
    "ITEM rows should remain owned until the command handler observes an item-use action")

local command_menu_handler = main:match(
    "local function check_command_menu%(frame_delta%)(.-)\nend\n\n%-%- check_yesno_prompt")
assert(command_menu_handler, "main.lua should expose check_command_menu before check_yesno_prompt")
local item_handler = command_menu_handler:match(
    "%-%- === ITEM sub%-menu mode ===(.-)%-%- === SPELL sub%-menu mode ===")
assert(item_handler, "check_command_menu should expose a distinct ITEM submenu branch")
assert_contains(item_handler,
    'trace_row1("CMD_ITEM_USE"',
    "an A-button item-use action should explicitly hand result dialogue back to the generic reader")
assert_contains(item_handler,
    'submenu_mode = "ITEM_RESULT"',
    "item use should enter a result-transition mode instead of immediately exposing stale inventory pixels")
assert_contains(item_handler,
    "CMD.item_result_cursor_clear = 0",
    "item-result transition mode should begin with no cursor-clear evidence")
assert_contains(command_menu_handler,
    'if submenu_mode == "ITEM_RESULT" then',
    "command-menu handling should own the item-result transition before merchant fallback scanning")
assert_contains(command_menu_handler,
    "has_visible_cursor_tile()",
    "item-result ownership should wait for the held-item cursor to disappear")
assert_contains(command_menu_handler,
    "CMD.item_result_cursor_clear + frame_delta",
    "item-result ownership should require consecutive cursor-clear frames instead of a fixed speech delay")
assert_contains(guard_source,
    'submenu_mode == "ITEM_RESULT"',
    "the generic dialogue reader should absorb stale list rows during the bounded item-result transition")

local function absorbs(mode, dialogue, menu_active)
    local source = table.concat({
        "local submenu_mode, dialogue, menu_active = ...",
        "local DW_QOL_STATE = {",
        "  command_menu_blocks_field_movement = function() return menu_active end,",
        "}",
        guard_source,
        "return submenu_absorbs_lower_dialogue(dialogue)",
    }, "\n")
    return assert(loadstring(source))(mode, dialogue, menu_active)
end

assert(absorbs("STATUS", "Gwaelin's Love", false) == true,
    "STATUS should continue absorbing its lower-window rows")
assert(absorbs("ITEM", "Silver Harp Cursed Belt Gwaelin's Love Torch", true) == true,
    "a live mixed-case ITEM list should remain absorbed")
assert(absorbs("ITEM", "'Bill, for this is Gwaelin.", false) == true,
    "cursor flicker alone should not release mixed-case ITEM rows to the generic reader")
assert(absorbs("ITEM", "COMMAND ITEM", false) == true,
    "uppercase ITEM transition noise should remain absorbed without a cursor")
assert(absorbs("SPELL", "RADIANT", false) == true,
    "uppercase SPELL list rows should remain absorbed")
assert(absorbs("SPELL", "But nothing happened.", false) == false,
    "lowercase SPELL result dialogue should continue reaching the generic reader")

print("test_item_result_dialogue.lua: item-result dialogue checks passed")
