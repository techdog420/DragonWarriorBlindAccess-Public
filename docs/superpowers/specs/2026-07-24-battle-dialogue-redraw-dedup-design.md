# Battle Dialogue Redraw Deduplication Design

Date: 2026-07-24

## Problem

Battle dialogue is sometimes announced repeatedly while the NES redraws the
same message. The redraw can move a stray period or show only a suffix of the
previous window, so the current character-exact overlap matcher treats the
redraw as new dialogue.

A live Wyvern battle on the world map at `(20,88)` produced this sequence for
one 29-point player attack:

1. `Bill attacks! The Wyvern's Hit. Points have been reduced by 29.`
2. `Bill attacks! The Wyvern's Hit Points have been. reduced by 29.`
3. `The Wyvern's Hit Points have been reduced by 29.`

All three variants were announced. Static replay through
`battle.normalize_dialogue()` and `battle.extract_new_text()` confirmed that
the current matcher returns each later redraw as new text.

## Goals

- Announce one combat action once when punctuation artifacts shift during a
  redraw.
- Suppress a suffix-only redraw when every word was already announced.
- Preserve immediate per-action battle narration.
- Preserve genuinely new counterattacks, victory text, rewards, and other
  appended dialogue.
- Prefer an occasional duplicate over suppressing uncertain new combat text.

## Non-Goals

This change will not:

- alter field, menu, NPC, or general dialogue extraction,
- delay narration until an entire battle page stabilizes,
- change the speech queue or speech timing thresholds,
- change PPU text reading,
- infer combat actions from game RAM, or
- address overworld autowalk timing.

Overworld autowalk will receive a separate evidence-gathering and design pass
after this battle-dialogue change is verified.

## Design

### Battle-only punctuation cleanup

Extend battle normalization only for punctuation patterns that cannot
reasonably represent a sentence boundary in the affected combat phrases.
Examples include `Hit. Points` and a period inserted before a lowercase
continuation word, as in `been. reduced`.

The cleanup improves spoken phrasing, but deduplication must not depend on a
complete catalog of these artifacts.

### Token-aware comparison

Keep the current normalized text for speech output. Build a separate,
comparison-only token view consisting of case-folded word and number tokens.
Punctuation and spacing do not participate in token equality.

Each token in the new text retains its start position in the normalized speech
text. This allows the matcher to compare punctuation-insensitively while
returning the original normalized wording for narration.

The battle extractor will apply these checks in order:

1. If the new token sequence is empty, return no text.
2. If the complete new token sequence already occurs contiguously in the
   previous token sequence, treat it as an already-announced redraw and return
   no text.
3. Otherwise, find the longest suffix of the previous token sequence that
   equals a prefix of the new token sequence.
4. When that overlap is meaningful, return the new normalized text beginning
   at the first unmatched token. This announces only an appended counterattack,
   reward, or other new suffix.
5. When token evidence is too weak or ambiguous, fall back to the existing
   conservative character-based extractor.

The token overlap must meet the existing spirit of the minimum-overlap guard:
short common phrases such as `The Wyvern` are not sufficient by themselves to
discard text. A contained redraw may be suppressed only when the complete new
message forms a meaningful multi-token sequence.

### Data flow

The runtime flow remains:

1. `main.lua` reads the visible battle dialogue.
2. `battle.normalize_dialogue()` prepares speech-safe battle text.
3. `battle.extract_new_text()` compares the previous and current battle text.
4. The existing coherence and sentence-completion checks decide when the
   returned new text is ready to speak.
5. The existing speech path announces it and records the current battle text.

Only steps 2 and 3 gain battle-specific punctuation and token handling. No
state or timing changes are required in `main.lua`.

## Safety and Failure Behavior

- Matching is restricted to battle dialogue, preventing a new heuristic from
  changing exploration or menu speech.
- Comparison tokens are never spoken; speech uses normalized source text.
- The matcher removes only a proven prefix or suppresses a complete contained
  redraw.
- Weak overlap falls back to current behavior, so uncertain text remains
  audible.
- The existing battle-state reset continues to delimit comparison history.
- Structured test cases will make the exact live failure reproducible without
  depending on emulator timing.

## Tests

Use test-driven development in `test_battle.lua`.

1. Add the exact three-message Wyvern sequence as a failing regression:
   - the first message is announced,
   - the second punctuation-shifted redraw returns no new text, and
   - the third suffix-only redraw returns no new text.
2. Verify battle normalization removes the known attached-dot artifacts
   without removing valid sentence punctuation.
3. Verify a redraw that appends an enemy counterattack returns the complete
   counterattack once.
4. Verify a redraw that appends victory or reward text returns that new suffix.
5. Verify short or ambiguous word overlap falls back to the conservative
   existing behavior.
6. Preserve all existing fast-action, coherence, exact-overlap, and
   normalization regressions.
7. Run the full battle test suite, Lua syntax checks for affected files, and
   `git diff --check`.

## Live Validation

After the user manually reloads the FCEUX Lua script:

1. Enter a battle and confirm command polling and battle-state logging are
   fresh.
2. Confirm each player attack and enemy action is narrated promptly.
3. Observe at least one scrolling or punctuation-shifted redraw.
4. Confirm the redraw is not re-announced.
5. Confirm victory and reward text remains audible.

If no punctuation-shifted redraw appears naturally, automated regression
coverage is sufficient to merge the narrow fix; additional live evidence can
be collected during continued play.
