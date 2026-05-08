-- scan_profiler.lua
-- BizHawk-only scheduler and PPU scan profiler for expensive screen readers.

local M = {
    enabled = false,
    -- Profiling collection is opt-in: even on BizHawk, M.call() runs as a plain
    -- pass-through unless recording is started. Avoids per-frame os.clock() and
    -- {fn(...)} tuple allocation on every wrapped call during normal play.
    recording = false,
    compat = nil,
    slots = {},
    profiles = {},
}

local table_unpack = unpack or table.unpack

function M.setup(compat)
    M.compat = compat or {}
    M.enabled = M.compat.is_bizhawk == true
end

function M.is_enabled()
    return M.enabled
end

function M.is_recording()
    return M.enabled and M.recording
end

function M.start_recording()
    if not M.enabled then return false end
    M.recording = true
    return true
end

function M.stop_recording()
    M.recording = false
end

function M.should_run(name, interval, frame_count)
    if not M.enabled then
        return true, 1
    end

    interval = math.max(1, math.floor(tonumber(interval) or 1))
    frame_count = math.floor(tonumber(frame_count) or 0)

    local slot = M.slots[name]
    if not slot then
        M.slots[name] = {last_frame = frame_count}
        return true, 1
    end

    local elapsed = frame_count - slot.last_frame
    if elapsed >= interval then
        slot.last_frame = frame_count
        return true, math.max(1, elapsed)
    end

    return false, 0
end

function M.stable_delta(frame_delta)
    if not M.enabled then
        return 1
    end
    return math.max(1, math.floor(tonumber(frame_delta) or 1))
end

local function record(label, read_delta, elapsed_ms)
    if not M.enabled then
        return
    end

    local profile = M.profiles[label]
    if not profile then
        profile = {
            calls = 0,
            reads = 0,
            max_reads = 0,
            ms = 0,
            max_ms = 0,
        }
        M.profiles[label] = profile
    end

    profile.calls = profile.calls + 1
    profile.reads = profile.reads + read_delta
    profile.ms = profile.ms + elapsed_ms
    if read_delta > profile.max_reads then
        profile.max_reads = read_delta
    end
    if elapsed_ms > profile.max_ms then
        profile.max_ms = elapsed_ms
    end
end

function M.call(label, fn, ...)
    -- Fast path: skip measurement when not recording. Avoids os.clock() syscall
    -- pairs and the {fn(...)} tuple allocation on every wrapped call.
    if not M.recording or not M.enabled or not (M.compat and M.compat.get_ppu_read_count) then
        return fn(...)
    end

    local reads_before = M.compat.get_ppu_read_count()
    local clock_before = os.clock()
    local results = {fn(...)}
    local elapsed_ms = (os.clock() - clock_before) * 1000
    local reads_after = M.compat.get_ppu_read_count()
    local read_delta = reads_after - reads_before
    if read_delta < 0 then
        read_delta = 0
    end
    record(label, read_delta, elapsed_ms)
    return table_unpack(results)
end

function M.reset()
    M.slots = {}
    M.profiles = {}
    if M.compat and M.compat.reset_ppu_stats then
        M.compat.reset_ppu_stats()
    end
end

function M.profile_lines()
    local rows = {}
    for label, profile in pairs(M.profiles) do
        rows[#rows + 1] = {
            label = label,
            calls = profile.calls,
            reads = profile.reads,
            max_reads = profile.max_reads,
            ms = profile.ms,
            max_ms = profile.max_ms,
        }
    end
    table.sort(rows, function(a, b)
        if a.reads ~= b.reads then
            return a.reads > b.reads
        end
        return a.label < b.label
    end)

    local lines = {}
    for _, row in ipairs(rows) do
        local avg_reads = row.calls > 0 and (row.reads / row.calls) or 0
        local avg_ms = row.calls > 0 and (row.ms / row.calls) or 0
        lines[#lines + 1] = string.format(
            "SCAN_PROFILE label=%s calls=%d reads=%d avg_reads=%.1f max_reads=%d ms=%.3f avg_ms=%.3f max_ms=%.3f",
            row.label,
            row.calls,
            row.reads,
            avg_reads,
            row.max_reads,
            row.ms,
            avg_ms,
            row.max_ms)
    end
    return lines
end

function M.ppu_stats_line()
    if not (M.compat and M.compat.get_ppu_stats_snapshot) then
        return "PPU_STATS unavailable"
    end
    local stats = M.compat.get_ppu_stats_snapshot()
    return string.format(
        "PPU_STATS reads=%d cache_hits=%d cache_misses=%d direct_reads=%d domain_reads=%d bulk_reads=%d bulk_bytes=%d cache_flushes=%d",
        stats.read_calls or 0,
        stats.cache_hits or 0,
        stats.cache_misses or 0,
        stats.direct_reads or 0,
        stats.domain_reads or 0,
        stats.bulk_reads or 0,
        stats.bulk_bytes or 0,
        stats.cache_flushes or 0)
end

return M
