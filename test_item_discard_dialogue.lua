-- test_item_discard_dialogue.lua
-- Source-surface regression checks for full-inventory discard speech ownership.

local function read_file(path)
    local file = assert(io.open(path, "rb"))
    local value = file:read("*a")
    file:close()
    return value
end

local function assert_contains(value, expected, message)
    if not value:find(expected, 1, true) then
        error(string.format("%s: missing %s", message, expected), 2)
    end
end

local main = read_file("main.lua")
local merchant_handler = main:match(
    "local function check_merchant_screen%(frame_delta%)(.-)\nend\n\nlocal function check_battle_menu")
assert(merchant_handler, "main.lua should expose check_merchant_screen before check_battle_menu")

assert_contains(
    merchant_handler,
    "if info.discard_prompt then",
    "discard prompts should take ownership before merchant offer speech"
)
assert_contains(
    merchant_handler,
    "local cursor_y = tonumber(snapshot.cursor_y)",
    "discard selection speech should use the live D9 inventory cursor"
)
assert_contains(
    merchant_handler,
    "items.get_item_at_d9(cursor_y)",
    "discard selection speech should resolve the live D9 item"
)
assert_contains(
    merchant_handler,
    'debug_tools.info("ITEM_DISCARD_OPEN',
    "discard screen entry should be logged explicitly"
)
assert_contains(
    merchant_handler,
    'debug_tools.info("ITEM_DISCARD_CURSOR',
    "discard cursor changes should be logged explicitly"
)
assert_contains(
    merchant_handler,
    "Inventory full. Choose an item to discard.",
    "discard screen entry should provide a concise accessible prompt"
)
assert_contains(
    main,
    "MER.active or MER.discard_active",
    "active discard screens should retain the responsive merchant-scan cadence"
)
assert_contains(
    main,
    "info.active or info.discard_prompt",
    "command-menu fallback scanning should treat discard screens as owned overlays"
)

print("test_item_discard_dialogue.lua: discard dialogue checks passed")
