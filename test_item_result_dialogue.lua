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
    "return DW_QOL_STATE.command_menu_blocks_field_movement()",
    "the live ITEM list should remain owned while its cursor is present")
assert_contains(guard_source,
    'or not tostring(dialogue or ""):find("[a-z]")',
    "lowercase item-result dialogue should reach the generic dialogue reader after the list cursor disappears")

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
assert(absorbs("ITEM", "'Bill, for this is Gwaelin.", false) == false,
    "Gwaelin's Love result dialogue should not be absorbed after the ITEM cursor disappears")
assert(absorbs("ITEM", "COMMAND ITEM", false) == true,
    "uppercase ITEM transition noise should remain absorbed without a cursor")
assert(absorbs("SPELL", "RADIANT", false) == true,
    "uppercase SPELL list rows should remain absorbed")
assert(absorbs("SPELL", "But nothing happened.", false) == false,
    "lowercase SPELL result dialogue should continue reaching the generic reader")

print("test_item_result_dialogue.lua: item-result dialogue checks passed")
