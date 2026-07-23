# GOLD Placeholder Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent the PPU decoder placeholder `[GOLD]` from leaking into ordinary lower-dialogue speech while preserving real `GOLD` words and prices.

**Architecture:** Keep the global `chars.lua` mapping intact. Remove only the exact literal placeholder while normalizing each filtered dialogue row in `text.lua`, before lowercase eligibility and row concatenation.

**Tech Stack:** Lua 5.1/LuaJIT, PPU test fixture in `test_text.lua`, FCEUX speech bridge logs.

## Global Constraints

- Do not modify `chars.lua`.
- Remove only the exact literal token `[GOLD]`.
- Preserve literal `GOLD`, reward quantities, shop prices, and merchant-generated speech.
- Do not broaden status-fragment heuristics beyond this placeholder.

---

### Task 1: Reproduce and filter placeholder leakage

**Files:**
- Modify: `test_text.lua:51`
- Modify: `test_text.lua:646`
- Modify: `text.lua:886`

**Interfaces:**
- Consumes: `text.read_dialogue_window_filtered(scroll_tiles, start_row, base_nametable)`.
- Produces: internal `strip_ppu_placeholder_noise(decoded) -> string`.

- [ ] **Step 1: Add a raw visible-tile test helper**

Add beside `write_visible_row`:

```lua
local function write_visible_tile(row, screen_col, byte, scroll_tiles, base_nametable)
    scroll_tiles = scroll_tiles or 0
    base_nametable = base_nametable or 0
    local virtual_col = scroll_tiles + screen_col
    local nt_col = virtual_col % 32
    local nt_index = (base_nametable + math.floor(virtual_col / 32)) % 2
    local base = (nt_index == 0) and 0x2000 or 0x2400
    ppu_bytes[base + row * 32 + nt_col] = byte
end
```

- [ ] **Step 2: Add failing TALK and STAIRS regressions**

Create two tests. Write the ordinary sentence with a blank at the contamination column, overwrite that blank with raw tile `0xF5`, and assert clean speech:

```lua
function tests.dialogue_filter_strips_gold_placeholder_from_talk_result()
    clear_ppu()
    write_visible_row(23, "There is no one       there.", 16, 0)
    write_visible_tile(23, 20, 0xF5, 16, 0)
    assert_equal(
        text.read_dialogue_window_filtered(16, 23, 0),
        "There is no one there.",
        "overworld background GOLD placeholder should not leak into TALK results"
    )
end

function tests.dialogue_filter_strips_gold_placeholder_from_stairs_result()
    clear_ppu()
    write_visible_row(23, "There are no stairs    here.", 16, 0)
    write_visible_tile(23, 20, 0xF5, 16, 0)
    assert_equal(
        text.read_dialogue_window_filtered(16, 23, 0),
        "There are no stairs here.",
        "overworld background GOLD placeholder should not leak into STAIRS results"
    )
end
```

Adjust only the blank-column indexes if the initial fixture does not place `0xF5` between the two lowercase phrases; do not change the expected behavior.

- [ ] **Step 3: Run the text test and verify RED**

Run: `lua test_text.lua`

Expected: both new tests fail with `[GOLD]` present in the actual dialogue.

- [ ] **Step 4: Implement exact placeholder removal**

Add before `filtered_dialogue_from_rows`:

```lua
local function strip_ppu_placeholder_noise(decoded)
    local cleaned = tostring(decoded or ""):gsub("%[GOLD%]", " ")
    cleaned = cleaned:gsub("%s+", " ")
    return cleaned:match("^%s*(.-)%s*$") or ""
end
```

Apply it as the first row cleanup step:

```lua
local cleaned = strip_ppu_placeholder_noise(decoded)
cleaned = strip_padded_status_suffix(cleaned)
```

- [ ] **Step 5: Run focused text verification**

Run:

```powershell
lua test_text.lua
luac -p text.lua test_text.lua
git diff --check
```

Expected: all text tests pass, both files byte-compile, and existing literal `GOLD` reward/price regressions remain green.

- [ ] **Step 6: Commit the dialogue fix**

```powershell
git add text.lua test_text.lua
git commit -m "fix: filter gold placeholder from dialogue"
```

### Task 2: Live speech verification

**Files:**
- Modify after proof: `work_notes/current_investigation.md`

**Interfaces:**
- Consumes: manually restarted FCEUX Lua script and `speech_bridge.log`.
- Produces: a clean TALK or STAIRS result on an affected overworld screen.

- [ ] **Step 1: Ask the user to restart `main.lua`**

The same restart used for the movement change may load this fix.

- [ ] **Step 2: Confirm the fresh script**

Run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait-ready gold_placeholder_filter report_position
```

Expected: the launcher marker and a fresh World Map position.

- [ ] **Step 3: Reproduce one command-menu response**

Have the user select TALK or STAIRS on an overworld cell whose background previously produced `0xF5`. Inspect `dw_debug.log` and `speech_bridge.log`.

Expected: `There is no one there.` or `There are no stairs here.` with no `[GOLD]`/spoken “gold”.

- [ ] **Step 4: Record verification**

Append the exact command, coordinate, spoken line, and fresh log session timestamp to `work_notes/current_investigation.md`.
