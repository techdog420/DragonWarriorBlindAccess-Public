-- test_battle.lua
-- Focused regression tests for battle command menu mapping.

local original_loaded = package.loaded["battle"]
package.loaded["battle"] = nil

local battle = require "battle"

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local tests = {}

function tests.maps_primary_battle_commands()
    assert_equal(battle.get_menu_item(0, 0), "FIGHT", "top-left should be FIGHT")
    assert_equal(battle.get_menu_item(1, 0), "SPELL", "top-right should be SPELL")
    assert_equal(battle.get_menu_item(0, 1), "RUN", "bottom-left should be RUN")
    assert_equal(battle.get_menu_item(1, 1), "ITEM", "bottom-right should be ITEM")
end

function tests.unknown_positions_return_nil()
    assert_equal(battle.get_menu_item(2, 0), nil, "unknown X should return nil")
    assert_equal(battle.get_menu_item(0, 2), nil, "unknown Y should return nil")
end

function tests.normalize_dialogue_strips_gold_macros_and_prompt_noise()
    local raw = "reduced by 3. The Red Slime attacks! .Thy Hit Points [GOLD][GOLD]decreased by 2. [GOLD]Command?"
    assert_equal(
        battle.normalize_dialogue(raw),
        "reduced by 3. The Red Slime attacks! Thy Hit Points decreased by 2.",
        "battle dialogue should drop leaked gold macros and command prompt"
    )
end

function tests.normalize_dialogue_preserves_reward_line()
    assert_equal(
        battle.normalize_dialogue("[GOLD]increases by 2."),
        "Gold increases by 2.",
        "real reward line should stay readable"
    )
end

function tests.normalize_dialogue_keeps_text_before_command_prompt()
    assert_equal(
        battle.normalize_dialogue("The Slime attacks! Thy Hit Points decreased by 1. Command? BILL attacks!"),
        "The Slime attacks! Thy Hit Points decreased by 1.",
        "battle dialogue should not merge command prompt and next action"
    )
end

function tests.normalize_dialogue_drops_truncated_damage_prefix()
    assert_equal(
        battle.normalize_dialogue("The Slime's Hit Points have been reduced by The Slime attacks!"),
        "The Slime attacks!",
        "truncated damage line should not be read ahead of the next action"
    )
end

function tests.extract_new_text_suppresses_suffix_repeat()
    assert_equal(
        battle.extract_new_text("A Red Slime draws near!", "near!"),
        "",
        "battle suffix-only repeat should be suppressed"
    )
end

function tests.extract_new_text_keeps_only_new_sentence_after_overlap()
    assert_equal(
        battle.extract_new_text(
            "BILL attacks! The Red Slime's Hit Points have been reduced by 2. The Red Slime attacks!",
            "The Red Slime's Hit Points have been reduced by 2. The Red Slime attacks! Thy Hit Point decreased by 1."
        ),
        "Thy Hit Point decreased by 1.",
        "battle overlap should keep only the newly revealed sentence"
    )
end

function tests.extract_new_text_trims_victory_prefix_overlap()
    assert_equal(
        battle.extract_new_text(
            "Thou hast done well in defeating the Red Slime.",
            "defeating the Red Slime. Thy Experience increases by 1. Thy GOLD increases by 2."
        ),
        "Thy Experience increases by 1. Thy GOLD increases by 2.",
        "victory page overlap should keep only new reward text"
    )
end

function tests.normalize_dialogue_removes_dot_artifacts()
    assert_equal(
        battle.normalize_dialogue("Thy Hit Point .decreased by 1. ..."),
        "Thy Hit Point decreased by 1.",
        "dot-border artifacts should be removed from battle text"
    )
end

function tests.is_coherent_dialogue_rejects_split_tokens()
    assert_equal(
        battle.is_coherent_dialogue("ntsThe Slime's Hit Poi y have been reduced b."),
        false,
        "split-token battle text should be rejected"
    )
end

function tests.is_coherent_dialogue_accepts_complete_sentence()
    assert_equal(
        battle.is_coherent_dialogue("The Slime attacks! Thy Hit Point decreased by 1."),
        true,
        "complete battle sentence should be accepted"
    )
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
    end
end

io.write(string.format("Ran %d Lua unit tests\n", total))

package.loaded["battle"] = original_loaded

if failures > 0 then
    os.exit(1)
end
