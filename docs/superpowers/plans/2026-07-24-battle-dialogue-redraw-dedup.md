# Battle Dialogue Redraw Deduplication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Announce each battle action once when scrolling redraws shift punctuation or expose an already-spoken suffix, while preserving prompt counterattack, victory, and reward narration.

**Architecture:** Keep all new behavior inside `battle.lua`. Normalize two proven attached-dot artifacts before speech, then compare old and new battle windows through private case-folded word-token views that retain source offsets; meaningful contained or prefix-overlap sequences are suppressed or trimmed, while weak evidence falls back to the existing character matcher.

**Tech Stack:** Lua 5.1, the repository's table-driven `test_battle.lua` harness, FCEUX live validation through `dw_commands.ps1` and `dw_debug.log`.

## Global Constraints

- Restrict matching changes to battle dialogue; do not alter field, menu, NPC, or general dialogue extraction.
- Preserve immediate per-action narration; do not wait for a whole battle page to stabilize.
- Preserve genuinely new counterattacks, victory text, rewards, and other appended dialogue.
- Prefer an occasional duplicate over suppressing uncertain new combat text.
- Do not change the speech queue, speech timing thresholds, PPU text reading, or `main.lua` battle-state flow.
- Do not address overworld autowalk in this implementation; it receives a separate investigation and design pass.
- Add no dependencies and remain compatible with Lua 5.1.

## File Structure

- Modify `battle.lua`: add battle-only attached-dot normalization and private token comparison helpers used by `extract_new_text()`.
- Modify `test_battle.lua`: reproduce the exact Wyvern redraw sequence and cover token containment, appended counterattack/reward extraction, and weak-overlap fallback.
- Modify `PLAYTESTING.md`: record automated and live behavior after the patch is exercised.
- Modify `session_handoff.md`: replace the unresolved-dialogue status with the current source/live validation state.
- Do not modify `main.lua`: its existing normalization, extraction, coherence, fast-action, and speech flow remains the integration point.
- Do not stage `work_notes/hauksness_stat_corruption_20260724.log`; it is unrelated raw evidence.

---

### Task 1: Normalize the proven attached-dot redraw artifacts

**Files:**
- Modify: `test_battle.lua:154-184`
- Modify: `battle.lua:138-187`

**Interfaces:**
- Consumes: `battle.normalize_dialogue(text: string) -> string`
- Produces: normalized `Hit. Points` and lowercase-continuation artifacts without changing valid sentence punctuation

- [ ] **Step 1: Add the failing normalization regression and exact live-sequence fixture**

Add these tests next to the existing dot-artifact normalization tests in
`test_battle.lua`:

```lua
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
```

- [ ] **Step 2: Run the battle suite and verify the new regression fails**

Run from PowerShell:

```powershell
wsl.exe bash -lc "cd /mnt/d/modding/DragonWarrior1 && lua5.1 test_battle.lua"
```

Expected: the existing 37 tests pass, and the new normalization/live-sequence
tests fail because `Hit. Points` and `been. reduced` remain unchanged.

- [ ] **Step 3: Add the minimal battle-only normalization**

In `battle.normalize_dialogue()`, place these substitutions immediately after
the existing `normalized:gsub("%.%.+", " ")` border-noise cleanup:

```lua
    -- Horizontal nametable alignment can place a border dot directly after a
    -- word while the battle window redraws. These two forms are continuations,
    -- not sentence boundaries.
    normalized = normalized:gsub("Hit%.%s+Points", "Hit Points")
    normalized = normalized:gsub("(%l)%.%s+(%l)", "%1 %2")
```

The first substitution handles the known capitalized label. The second removes
a period only when both surrounding letters are lowercase, so a normal
boundary such as `The Wyvern attacks. Bill attacks!` remains intact.

- [ ] **Step 4: Run focused tests and syntax validation**

Run:

```powershell
wsl.exe bash -lc "cd /mnt/d/modding/DragonWarrior1 && lua5.1 test_battle.lua && luac5.1 -p battle.lua test_battle.lua"
```

Expected: `Ran 39 Lua unit tests`, no `FAIL` lines, and `luac5.1` exits with no
output.

- [ ] **Step 5: Commit the independently useful normalization**

Run:

```powershell
git add -- battle.lua test_battle.lua
git diff --cached --check
git commit -m "fix: normalize attached battle redraw dots"
```

Expected: only `battle.lua` and `test_battle.lua` are included.

---

### Task 2: Deduplicate punctuation-insensitive battle redraws by word tokens

**Files:**
- Modify: `test_battle.lua:124-184`
- Modify: `battle.lua:14-15`
- Modify: `battle.lua:189-225`

**Interfaces:**
- Consumes: `battle.extract_new_text(old_text: string, new_text: string) -> string`
- Produces: private `dialogue_tokens()`, `meaningful_token_range()`, `token_ranges_equal()`, `contains_token_sequence()`, and `longest_token_overlap()` helpers
- Preserves: the public `extract_new_text()` signature and the existing character-exact fallback

- [ ] **Step 1: Add failing token-aware extraction regressions**

Add these tests after the existing `extract_new_text_*` cases in
`test_battle.lua`:

```lua
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
```

- [ ] **Step 2: Run the suite and verify the token regressions fail for the intended reason**

Run:

```powershell
wsl.exe bash -lc "cd /mnt/d/modding/DragonWarrior1 && lua5.1 test_battle.lua"
```

Expected: the 39 Task 1 tests remain green. The four new tests fail because the
current extractor either returns the full punctuation-shifted redraw or cannot
trim the punctuation-insensitive prefix.

- [ ] **Step 3: Add private token comparison helpers**

Below `OVERLAP_MIN_LEN` in `battle.lua`, add:

```lua
local TOKEN_OVERLAP_MIN_COUNT = 3

local function dialogue_tokens(text)
    local tokens = {}
    local lower = tostring(text or ""):lower()
    local cursor = 1

    while cursor <= #lower do
        local first, last = lower:find("[a-z0-9][a-z0-9']*", cursor)
        if not first then
            break
        end
        tokens[#tokens + 1] = {
            value = lower:sub(first, last),
            first = first,
        }
        cursor = last + 1
    end

    return tokens
end

local function meaningful_token_range(tokens, first, count)
    if count < TOKEN_OVERLAP_MIN_COUNT then
        return false
    end

    local character_count = 0
    for index = first, first + count - 1 do
        character_count = character_count + #tokens[index].value
    end
    return character_count >= OVERLAP_MIN_LEN
end

local function token_ranges_equal(left, left_first, right, right_first, count)
    for offset = 0, count - 1 do
        if left[left_first + offset].value ~= right[right_first + offset].value then
            return false
        end
    end
    return true
end

local function contains_token_sequence(old_tokens, new_tokens)
    local count = #new_tokens
    if count > #old_tokens or not meaningful_token_range(new_tokens, 1, count) then
        return false
    end

    for first = 1, #old_tokens - count + 1 do
        if token_ranges_equal(old_tokens, first, new_tokens, 1, count) then
            return true
        end
    end
    return false
end

local function longest_token_overlap(old_tokens, new_tokens)
    local maximum = math.min(#old_tokens, #new_tokens)
    for count = maximum, 1, -1 do
        local old_first = #old_tokens - count + 1
        if meaningful_token_range(new_tokens, 1, count)
            and token_ranges_equal(old_tokens, old_first, new_tokens, 1, count) then
            return count
        end
    end
    return 0
end
```

These helpers are private. Token comparison ignores case and punctuation, while
the stored `first` offset maps an unmatched token back into the normalized text
that should be spoken.

- [ ] **Step 4: Integrate token evidence before the character-exact fallback**

In `battle.extract_new_text()`, keep the current empty, equality, and literal
containment checks. Immediately after the current `old:find(new, 1, true)`
block, insert:

```lua
    local old_tokens = dialogue_tokens(old)
    local new_tokens = dialogue_tokens(new)

    if contains_token_sequence(old_tokens, new_tokens) then
        return ""
    end

    local token_overlap = longest_token_overlap(old_tokens, new_tokens)
    if token_overlap > 0 then
        if token_overlap == #new_tokens then
            return ""
        end

        local remainder = new:sub(new_tokens[token_overlap + 1].first)
        remainder = remainder:match("^%s*(.-)%s*$") or remainder
        return remainder
    end
```

Leave the existing `for start = 1, #old do` character-suffix loop immediately
after this block. That loop remains the fallback when token overlap is absent
or shorter than three meaningful tokens.

- [ ] **Step 5: Run the battle suite and syntax checks**

Run:

```powershell
wsl.exe bash -lc "cd /mnt/d/modding/DragonWarrior1 && lua5.1 test_battle.lua && luac5.1 -p battle.lua test_battle.lua main.lua"
```

Expected: `Ran 43 Lua unit tests`, no `FAIL` lines, and `luac5.1` exits with no
output. The existing fast-action, exact-overlap, victory, reward, spell, and
coherence cases must remain green.

- [ ] **Step 6: Inspect scope and commit the token matcher**

Run:

```powershell
git diff --check
git diff -- battle.lua test_battle.lua
git status --short
git add -- battle.lua test_battle.lua
git diff --cached --check
git commit -m "fix: deduplicate battle dialogue redraws"
```

Expected: production behavior changes only in `battle.lua`; test coverage
changes only in `test_battle.lua`; the unrelated raw Hauksness log remains
untracked.

---

### Task 3: Verify live narration and publish the resulting project state

**Files:**
- Modify: `PLAYTESTING.md:2453-2460`
- Modify: `session_handoff.md:48-57`
- Read: `dw_debug.log`
- Read: `speech_bridge.log`

**Interfaces:**
- Consumes: the Task 2 battle extractor and the existing FCEUX command queue
- Produces: live evidence that action/reward narration remains prompt and an accurate handoff state

- [ ] **Step 1: Run the complete automated verification gate**

Run:

```powershell
wsl.exe bash -lc "cd /mnt/d/modding/DragonWarrior1 && lua5.1 test_battle.lua && luac5.1 -p battle.lua test_battle.lua main.lua"
git diff --check
git status --short --branch
```

Expected: all 43 battle tests pass; syntax and whitespace checks are clean;
only intentional documentation work and the unrelated untracked diagnostic
log may remain.

- [ ] **Step 2: Pause for the user's manual FCEUX Lua restart**

Tell the user:

```text
The source and automated tests are ready. Please use Restart in FCEUX's Lua
Script Control, then tell me when the script is running again.
```

Do not treat source-on-disk results as live until the user confirms the manual
restart.

- [ ] **Step 3: Prove fresh command polling and battle baseline**

After restart confirmation, run:

```powershell
.\dw_commands.ps1 --replace --wait-ready BATTLE_DEDUP --timeout 15 report_position speech_status
```

Expected: a fresh `LAUNCHER_PROBE: BATTLE_DEDUP` log line, current position,
and live speech status. If the command times out, stop and repair polling
before gathering battle evidence.

- [ ] **Step 4: Validate one live battle without taking control from the user**

Ask the user to handle the fight. During the fight, inspect fresh evidence:

```powershell
Get-Content -LiteralPath .\dw_debug.log -Tail 240
Get-Content -LiteralPath .\speech_bridge.log -Tail 120
```

Success requires:

- the opening and each genuinely new attack/damage action remain prompt,
- counterattacks are not trimmed away,
- victory and reward lines remain audible, and
- any punctuation-shifted or suffix-only redraw is not spoken again.

If the fight produces no redraw, record that ordinary action and reward speech
passed live while redraw suppression remains covered by the exact automated
fixture. Do not prolong route work merely to force another random encounter.

- [ ] **Step 5: Update playtesting and handoff with the exact observed state**

Append this verified behavior to the existing combat-action section in
`PLAYTESTING.md` when a redraw occurs:

```markdown
- Combat sliding-window redraw deduplication: the live Wyvern sequence from
  World Map `(20,88)` is now an automated regression. Battle-only
  normalization removes attached `Hit. Points` and `been. reduced` artifacts,
  while a three-token/eight-character word matcher suppresses contained
  redraws and returns only genuine appended counterattack or reward text.
  All 43 battle tests and Lua syntax checks pass. A post-reload FCEUX battle
  confirmed prompt action/reward narration and did not repeat its shifted
  redraw.
```

If the validation fight does not naturally redraw, use this final sentence
instead:

```markdown
  All 43 battle tests and Lua syntax checks pass. A post-reload FCEUX battle
  confirmed prompt action/reward narration but did not naturally produce a
  shifted redraw; suppression remains verified by the exact captured fixture.
```

Replace the unresolved-dialogue sentence in `session_handoff.md` with the
matching current status. For a live redraw success, use:

```markdown
  The coordinate-sensitive combat sliding-window bug is source-patched and
  live-verified: battle-only token comparison suppresses punctuation-shifted
  and suffix-only redraws while preserving appended counterattacks and
  rewards. The exact World Map `(20,88)` Wyvern sequence is covered by the
  43/43 battle regression suite.
```

If no live redraw occurred, use:

```markdown
  The coordinate-sensitive combat sliding-window bug is source-patched and
  automated-verified: the exact World Map `(20,88)` Wyvern sequence is covered
  by the 43/43 battle regression suite. Post-reload action/reward narration
  passed, but a naturally shifted redraw still awaits live confirmation.
```

- [ ] **Step 6: Commit and publish the verified state**

Run:

```powershell
git add -- PLAYTESTING.md session_handoff.md
git diff --cached --check
git commit -m "docs: record battle dialogue dedup validation"
git push origin codex/battle-dialogue-autowalk-tuning
git status --short --branch
```

Expected: the branch matches
`origin/codex/battle-dialogue-autowalk-tuning`; draft PR #3 contains the design,
plan, implementation, tests, and validation notes; the unrelated raw
Hauksness diagnostic log remains untracked.

Do not begin overworld autowalk tuning in this task. Start that work with a
fresh baseline, focused timing evidence, and its own approved design.
