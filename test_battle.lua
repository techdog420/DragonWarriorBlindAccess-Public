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

function tests.detects_battle_spell_list_from_upper_text()
    assert_equal(
        battle.is_spell_screen_text(
            ".. [GOLD][GOLD] COMMAND [GOLD] Bill FIGHSPELL LV   4 RUN HEAL HP  22 HURT MP  14",
            {{name = "Heal"}, {name = "Hurt"}}
        ),
        true,
        "battle spell list should be recognized when known spell names are visible"
    )
end

function tests.top_level_spell_command_is_not_spell_list()
    assert_equal(
        battle.is_spell_screen_text(
            "COMMAND Bill FIGHT SPELL LV   4 RUN ITEM HP  22 MP  14",
            {{name = "Heal"}, {name = "Hurt"}}
        ),
        false,
        "top-level SPELL command alone should not be treated as the spell list"
    )
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

function tests.normalize_dialogue_removes_leaked_gold_reward_macros()
    assert_equal(
        battle.normalize_dialogue("Thy Experience Gold increases by 1. Thy GOLD Gold increases by 2."),
        "Thy Experience increases by 1. Thy GOLD increases by 2.",
        "leaked gold macro text should not duplicate reward labels"
    )
end

function tests.normalize_dialogue_removes_leaked_gold_from_levelup_stat_labels()
    assert_equal(
        battle.normalize_dialogue("Thy power increases by 4. Thy Response Speed Gold increases by 6."),
        "Thy power increases by 4. Thy Response Speed increases by 6.",
        "leaked gold macro text should not split level-up stat labels"
    )
    assert_equal(
        battle.normalize_dialogue("Thy Maximum Hit Points Gold increase by 6."),
        "Thy Maximum Hit Points increase by 6.",
        "leaked gold macro text should not split max-stat level-up labels"
    )
end

function tests.extract_new_text_uses_normalized_levelup_overlap_after_gold_artifact_cleanup()
    local old = battle.normalize_dialogue("Thy power increases by 4. Thy Response Speed Gold increases by 6.")
    local new = battle.normalize_dialogue("Thy power increases by 4. Thy Response Speed increases by 6. Thy Maximum Hit Points Gold increase by 6.")

    assert_equal(
        battle.extract_new_text(old, new),
        "Thy Maximum Hit Points increase by 6.",
        "level-up stat overlap should not repeat earlier lines after gold artifacts are removed"
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

function tests.normalize_dialogue_preserves_action_before_truncated_damage()
    assert_equal(
        battle.normalize_dialogue("Bill attacks! The Slime's Hit Points have been reduced by Thou hast done well in defeating the Slime."),
        "Bill attacks! Thou hast done well in defeating the Slime.",
        "complete action text should survive when one-hit-kill damage is truncated"
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

function tests.extract_new_text_suppresses_equivalent_words_with_other_punctuation()
    assert_equal(
        battle.extract_new_text(
            "Bill attacks! The Wyvern dodges! No damage hath been scored!",
            "Bill attacks. The Wyvern dodges. No damage hath been scored."
        ),
        "",
        "punctuation-only redraw changes should not repeat an announced action"
    )
end

function tests.extract_new_text_keeps_counterattack_after_token_overlap()
    assert_equal(
        battle.extract_new_text(
            "Bill attacks! The Wyvern's Hit Points have been reduced by 29.",
            "The Wyvern's Hit Points have been reduced by 29! The Wyvern attacks! Thy Hit Point decreased by 8."
        ),
        "The Wyvern attacks! Thy Hit Point decreased by 8.",
        "punctuation-insensitive overlap should keep the appended counterattack"
    )
end

function tests.extract_new_text_keeps_rewards_after_token_overlap()
    assert_equal(
        battle.extract_new_text(
            "Thou hast done well in defeating the Wyvern.",
            "defeating the Wyvern! Thy Experience increases by 34. Thy GOLD increases by 90."
        ),
        "Thy Experience increases by 34. Thy GOLD increases by 90.",
        "punctuation-insensitive overlap should keep appended rewards"
    )
end

function tests.extract_new_text_does_not_use_two_token_ambiguous_overlap()
    assert_equal(
        battle.extract_new_text(
            "Bill watches The Wyvern.",
            "The Wyvern attacks!"
        ),
        "The Wyvern attacks!",
        "two common tokens should not be enough to trim new battle text"
    )
end

function tests.normalize_dialogue_removes_dot_artifacts()
    assert_equal(
        battle.normalize_dialogue("Thy Hit Point .decreased by 1. ..."),
        "Thy Hit Point decreased by 1.",
        "dot-border artifacts should be removed from battle text"
    )
end

function tests.normalize_dialogue_removes_spaced_dot_artifacts()
    assert_equal(
        battle.normalize_dialogue("Bill attacks! The Red Slime's Hit . Points have been . reduced by 5. ."),
        "Bill attacks! The Red Slime's Hit Points have been reduced by 5.",
        "spaced dot artifacts should not make the same battle line look new"
    )
end

function tests.normalize_dialogue_removes_attached_dot_artifacts_without_erasing_sentences()
    assert_equal(
        battle.normalize_dialogue(
            "The Wyvern attacks. Bill attacks! The Wyvern's Hit. Points have been. reduced by 29."
        ),
        "The Wyvern attacks. Bill attacks! The Wyvern's Hit Points have been reduced by 29.",
        "attached redraw dots should be removed without erasing a real sentence boundary"
    )
end

function tests.extract_new_text_suppresses_live_wyvern_redraw_sequence()
    local first = battle.normalize_dialogue(
        "Bill attacks! The Wyvern's Hit. Points have been reduced by 29."
    )
    local shifted = battle.normalize_dialogue(
        "Bill attacks! The Wyvern's Hit Points have been. reduced by 29."
    )
    local suffix = battle.normalize_dialogue(
        "The Wyvern's Hit Points have been reduced by 29."
    )

    assert_equal(
        first,
        "Bill attacks! The Wyvern's Hit Points have been reduced by 29.",
        "the first live Wyvern message should be speech-safe"
    )
    assert_equal(
        shifted,
        first,
        "the punctuation-shifted redraw should normalize to the first message"
    )
    assert_equal(
        battle.extract_new_text("", first),
        first,
        "the first combat action should still be announced"
    )
    assert_equal(
        battle.extract_new_text(first, shifted),
        "",
        "the punctuation-shifted redraw should not repeat"
    )
    assert_equal(
        battle.extract_new_text(first, suffix),
        "",
        "the already-announced suffix redraw should not repeat"
    )
end

function tests.normalize_dialogue_removes_reward_spaced_dot_artifacts()
    assert_equal(
        battle.normalize_dialogue("Thy Experience . increases by 1. Thy GOLD increases by 2."),
        "Thy Experience increases by 1. Thy GOLD increases by 2.",
        "spaced dot artifacts should be removed from reward text too"
    )
end

function tests.normalize_dialogue_removes_opening_trailing_dot_artifact()
    assert_equal(
        battle.normalize_dialogue("A Red Slime draws near! ."),
        "A Red Slime draws near!",
        "opening battle line should not keep a stray border dot after punctuation"
    )
end

function tests.is_coherent_dialogue_rejects_split_tokens()
    assert_equal(
        battle.is_coherent_dialogue("ntsThe Slime's Hit Poi y have been reduced b."),
        false,
        "split-token battle text should be rejected"
    )
end

function tests.is_coherent_dialogue_rejects_live_magiwyvern_spell_result_splice()
    assert_equal(
        battle.is_coherent_dialogue(
            "Bill attacks! It is dodging! Magiwyvern chants the spell of Thou art asleep."
        ),
        false,
        "a sleep-result redraw must not be accepted as the enemy's spell name"
    )
    assert_equal(
        battle.is_coherent_dialogue("Magiwyvern chants the spell of SLEEP. Thou art asleep."),
        true,
        "the clean spell and result page must remain available for narration"
    )
end

function tests.is_coherent_dialogue_rejects_live_magiwyvern_damage_suffix_redraw()
    assert_equal(
        battle.is_coherent_dialogue(
            "Points have been reduced by 41. Magiwyvern chants the spell of Thou art asleep."
        ),
        false,
        "a clipped prior damage suffix must not make a transitional spell page coherent"
    )
    assert_equal(
        battle.is_coherent_dialogue(
            "reduced by 41. Magiwyvern chants the spell of SLEEP. Thou art asleep."
        ),
        false,
        "a redraw beginning mid-damage sentence must wait for a clean page"
    )
end

function tests.is_coherent_dialogue_accepts_complete_sentence()
    assert_equal(
        battle.is_coherent_dialogue("The Slime attacks! Thy Hit Point decreased by 1."),
        true,
        "complete battle sentence should be accepted"
    )
end

function tests.complete_sentence_prefix_keeps_ready_action_text()
    assert_equal(
        battle.complete_sentence_prefix("Bill attacks! The Drakee's Hit Points have been reduced by"),
        "Bill attacks!",
        "battle action speech can be announced before the whole page is done"
    )
end

function tests.complete_sentence_prefix_accepts_multiple_complete_sentences()
    assert_equal(
        battle.complete_sentence_prefix("Bill attacks! The Drakee's Hit Points have been reduced by 3. The Drakee"),
        "Bill attacks! The Drakee's Hit Points have been reduced by 3.",
        "all complete battle sentences in the current prefix should be speakable"
    )
end

function tests.complete_sentence_prefix_rejects_partial_text()
    assert_equal(
        battle.complete_sentence_prefix("The Drakee's Hit Points have been reduced by"),
        "",
        "partial battle text should not be announced"
    )
end

function tests.fast_action_dialogue_accepts_damage_and_attacks()
    assert_equal(
        battle.is_fast_action_dialogue("Bill attacks! The Drakee's Hit Points have been reduced by 3."),
        true,
        "action and damage lines should be eligible for fast battle speech"
    )
end

function tests.fast_action_dialogue_rejects_rewards()
    assert_equal(
        battle.is_fast_action_dialogue("Thou hast done well in defeating the Drakee. Thy Experience increases by 2."),
        false,
        "victory and reward text should keep the stable battle dialogue path"
    )
end

function tests.fast_action_prefix_stops_before_rewards()
    assert_equal(
        battle.fast_action_prefix("Bill attacks! Thou hast done well in defeating the Slime."),
        "Bill attacks!",
        "fast battle speech should preserve the action prefix before reward text"
    )
end

function tests.fast_action_prefix_keeps_damage_before_rewards()
    assert_equal(
        battle.fast_action_prefix("Bill attacks! The Red Slime's Hit Points have been reduced by 5. Thou hast done well in defeating the Red Slime."),
        "Bill attacks! The Red Slime's Hit Points have been reduced by 5.",
        "fast battle speech should keep completed damage before reward text"
    )
end

function tests.fast_action_prefix_stops_before_spell_and_status_sentences()
    assert_equal(
        battle.fast_action_prefix(
            "Bill attacks! It is dodging! Magiwyvern chants the spell of SLEEP. Thou art asleep."
        ),
        "Bill attacks! It is dodging!",
        "fast action speech must not absorb later spell and status sentences"
    )
    assert_equal(
        battle.fast_action_prefix(
            "Bill attacks! It is dodging! Magiwyvern chants the spell of Thou art asleep."
        ),
        "",
        "a complete but incoherent redraw must not repeat its valid action prefix"
    )
end

function tests.terminal_dragonlord_victory_requires_interrupting_speech()
    assert_equal(
        battle.is_terminal_victory_dialogue("Thou hast done well in defeating the Dragonlord."),
        true,
        "the final Dragonlord victory must interrupt stale queued combat speech"
    )
    assert_equal(
        battle.is_terminal_victory_dialogue("Thou hast done well in defeating the Drakee."),
        false,
        "ordinary battle victories should retain queued speech"
    )
end

function tests.detects_sleep_and_stopspell_flags()
    assert_equal(battle.is_hero_asleep(0x80), true, "sleep flag should be detected from combat flags")
    assert_equal(battle.is_hero_asleep(0x10), false, "stopspell bit alone should not look asleep")
    assert_equal(battle.is_hero_stopspelled(0x10), true, "stopspell flag should be detected from combat flags")
    assert_equal(battle.is_hero_stopspelled(0x80), false, "sleep bit alone should not look stopspelled")
end

function tests.describe_hero_status_change_reports_sleep_transitions()
    assert_equal(
        battle.describe_hero_status_change(0x00, 0x80),
        "Asleep.",
        "new sleep status should announce asleep"
    )
    assert_equal(
        battle.describe_hero_status_change(0x80, 0x00),
        "Awake.",
        "cleared sleep status should announce awake"
    )
end

function tests.describe_hero_status_change_reports_stopspell_transitions()
    assert_equal(
        battle.describe_hero_status_change(0x00, 0x10),
        "Spells blocked.",
        "new stopspell status should announce spell blocking"
    )
    assert_equal(
        battle.describe_hero_status_change(0x10, 0x00),
        "Spells restored.",
        "cleared stopspell should announce spell access restored"
    )
end

function tests.describe_hero_status_change_joins_multiple_transitions()
    assert_equal(
        battle.describe_hero_status_change(0x00, 0x90),
        "Asleep. Spells blocked.",
        "simultaneous sleep and stopspell should announce both"
    )
    assert_equal(
        battle.describe_hero_status_change(0x90, 0x90),
        "",
        "unchanged combat flags should not announce duplicate status"
    )
end

function tests.spell_menu_status_prefix_only_warns_when_stopspelled()
    assert_equal(
        battle.spell_menu_status_prefix(0x10),
        "Spells blocked. ",
        "battle spell menu should warn when stopspelled"
    )
    assert_equal(
        battle.spell_menu_status_prefix(0x00),
        "",
        "battle spell menu should stay quiet when spells are available"
    )
end

function tests.describe_spell_selection_adds_balanced_stopspell_reminder()
    assert_equal(
        battle.describe_spell_selection("Heal. 4 MP", 0x10, true),
        "Spells blocked. Heal. 4 MP",
        "battle spell entry should warn when the hero is stopspelled"
    )
    assert_equal(
        battle.describe_spell_selection("Heal. 4 MP", 0x00, true),
        "Spells. Heal. 4 MP",
        "battle spell entry should keep the normal intro when spells are available"
    )
    assert_equal(
        battle.describe_spell_selection("Hurt. 2 MP", 0x10, false),
        "Hurt. 2 MP",
        "battle spell cursor moves should not keep repeating the stopspell warning"
    )
end

function tests.spell_command_unavailable_prioritizes_stopspell_over_empty_list()
    assert_equal(
        battle.describe_spell_command_unavailable(0x10, 0),
        "Spells blocked.",
        "stopspell should explain why SPELL is unavailable even if the game hides the list"
    )
    assert_equal(
        battle.describe_spell_command_unavailable(0x00, 0),
        "Spells. Empty.",
        "empty spell list should still be explicit when no stopspell flag is active"
    )
    assert_equal(
        battle.describe_spell_command_unavailable(0x00, 3),
        nil,
        "known spells with no stopspell should allow normal spell menu handling"
    )
end

function tests.spell_command_unavailable_treats_missing_spell_bits_with_mp_as_blocked()
    assert_equal(
        battle.describe_spell_command_unavailable(0x00, 0, {level = 12, mp = 48}),
        "Spells blocked.",
        "a level 12 hero with MP should not be described as having an empty spell list"
    )
    assert_equal(
        battle.describe_spell_command_unavailable(0x00, 0, {level = 1, mp = 0}),
        "Spells. Empty.",
        "a low-level hero with no MP should still get the genuine empty-list message"
    )
end

function tests.spell_command_unavailable_can_ignore_stopspell_for_field_menus()
    assert_equal(
        battle.describe_spell_command_unavailable(0x10, 7, {level = 13, mp = 57}, {ignore_stopspell = true}),
        nil,
        "field spell menus should ignore stale battle stopspell flags when spells are known"
    )
    assert_equal(
        battle.describe_spell_command_unavailable(0x10, 0, {level = 1, mp = 0}, {ignore_stopspell = true}),
        "Spells. Empty.",
        "ignoring stopspell should still preserve genuine empty field spell menus"
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
