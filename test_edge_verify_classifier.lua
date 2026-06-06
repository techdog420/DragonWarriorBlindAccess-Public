-- test_edge_verify_classifier.lua
-- Focused unit tests for edge verification classification.

local classifier = require "edge_verify_classifier"

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or "assert_equal failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local tests = {}

function tests.teleport_artifact_pattern_is_inconclusive()
    local classification = classifier.classify("complete", {
        moved = 1,
        blocked = 4,
        blocked_model_mismatch = 4,
        timed_out = 0,
        refused = 0,
        drifted = 0,
        map_changed = 0,
        interrupted = 0,
    }, {
        attempts = 5,
        first_attempt_status = "moved",
        blocked_after_move_count = 4,
        blocked_after_move_mismatch_count = 4,
        moved_after_blocked_count = 0,
    })

    assert_equal(
        classification,
        "inconclusive_teleport_artifact",
        "moved-then-open-preview-block verifier runs should expose teleport artifact risk"
    )
end

function tests.ordinary_mixed_result_stays_mixed()
    local classification = classifier.classify("complete", {
        moved = 2,
        blocked = 3,
        blocked_model_mismatch = 1,
        timed_out = 0,
        refused = 0,
        drifted = 0,
        map_changed = 0,
        interrupted = 0,
    }, {
        attempts = 5,
        first_attempt_status = "blocked",
        blocked_after_move_count = 1,
        blocked_after_move_mismatch_count = 1,
        moved_after_blocked_count = 2,
    })

    assert_equal(
        classification,
        "mixed",
        "mixed runs without the teleport artifact signature should stay mixed"
    )
end

function tests.confirmed_passable_model_mismatch_stays_suspect_passable()
    local classification = classifier.classify("complete", {
        moved = 6,
        blocked = 0,
        moved_model_mismatch = 6,
        blocked_model_mismatch = 0,
        timed_out = 0,
        refused = 0,
        drifted = 0,
        map_changed = 0,
        interrupted = 0,
    }, {
        attempts = 6,
        first_attempt_status = "moved",
    })

    assert_equal(
        classification,
        "suspect_passable_model_mismatch",
        "clean moved repeats through a modeled block should keep the existing suspect-passable classification"
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

if failures > 0 then
    os.exit(1)
end
