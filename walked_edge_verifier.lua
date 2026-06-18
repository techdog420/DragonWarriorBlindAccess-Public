-- walked_edge_verifier.lua
-- Non-teleport edge/door verification helpers for live map decoding.

local M = {}

local BUILD_TAG = "direct_route route_drift_wait route_stop_cleanup"

local CARDINAL_TO_KEY = {north = "up", south = "down", east = "right", west = "left"}

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function parse_int(value)
    value = trim(value)
    if value == "" then
        return nil
    end
    if not value:match("^%-?%d+$") then
        return nil
    end
    return tonumber(value)
end

local function normalize_dir(value, dir_to_delta)
    local dir = trim(value):lower()
    dir = CARDINAL_TO_KEY[dir] or dir
    if not dir_to_delta or not dir_to_delta[dir] then
        return nil
    end
    return dir
end

local function parse_parts(arg)
    local parts = {}
    for part in tostring(arg or ""):gmatch("[^,]+") do
        parts[#parts + 1] = trim(part)
    end
    return parts
end

local function parse_edge_arg(arg, dir_to_delta, default_x, default_y)
    local parts = parse_parts(arg)
    if #parts == 1 then
        local dir = normalize_dir(parts[1], dir_to_delta)
        if dir and default_x ~= nil and default_y ~= nil then
            return default_x, default_y, dir
        end
        return nil
    end
    if #parts ~= 3 then
        return nil
    end
    local x = parse_int(parts[1])
    local y = parse_int(parts[2])
    local dir = normalize_dir(parts[3], dir_to_delta)
    if x == nil or y == nil or not dir then
        return nil
    end
    return x, y, dir
end

local function parse_stand_arg(arg, dir_to_delta)
    local parts = parse_parts(arg)
    if #parts ~= 3 then
        return nil
    end
    local x = parse_int(parts[1])
    local y = parse_int(parts[2])
    local dir = normalize_dir(parts[3], dir_to_delta)
    if x == nil or y == nil or not dir then
        return nil
    end
    return x, y, dir
end

local function format_map_id(map_id)
    return string.format("0x%02X", tonumber(map_id) or -1)
end

local function snapshot_contains(snapshot, x, y)
    for _, slot in ipairs(snapshot and snapshot.slots or {}) do
        if tonumber(slot.x) == x and tonumber(slot.y) == y then
            return true
        end
    end
    return false
end

local function format_slots(snapshot)
    local slots = snapshot and snapshot.slots or {}
    if #slots == 0 then
        return "none"
    end
    local parts = {}
    for i, slot in ipairs(slots) do
        local index = slot.index
        if index == nil then
            index = i - 1
        end
        parts[#parts + 1] = string.format("%s=(%s,%s)",
            tostring(index),
            tostring(slot.x),
            tostring(slot.y))
    end
    return table.concat(parts, " ")
end

local Controller = {}
Controller.__index = Controller

local function noop() end

function M.new(deps)
    deps = deps or {}
    local controller = setmetatable({
        deps = deps,
        pending = nil,
        door_state = nil,
    }, Controller)
    local log_info = deps.log_info or deps.log or noop
    log_info("WALKED_EDGE_VERIFIER_BUILD " .. BUILD_TAG)
    return controller
end

function Controller:_info(msg)
    (self.deps.log_info or self.deps.log or noop)(msg)
end

function Controller:_error(msg)
    (self.deps.log_error or self.deps.log or noop)(msg)
end

function Controller:_speak(msg)
    (self.deps.speak or noop)(msg)
end

function Controller:_stop_route(reason)
    (self.deps.stop_route or noop)(reason)
end

function Controller:_position()
    local get_position = self.deps.get_position
    if not get_position then
        return nil, nil, nil
    end
    return get_position()
end

function Controller:_door_snapshot()
    local snapshot = self.deps.door_snapshot
    if not snapshot then
        return {keys = nil, slots = {}}
    end
    local result = snapshot()
    if type(result) ~= "table" then
        return {keys = nil, slots = {}}
    end
    result.slots = result.slots or {}
    return result
end

function Controller:_route_to_origin(state)
    local route_to = self.deps.route_to
    if not route_to then
        return false, "route_unavailable"
    end
    local target = {
        id = string.format("walked_verify_%s_%d_%d_%s",
            tostring(state.kind),
            state.origin_x,
            state.origin_y,
            tostring(state.dir)),
        name = state.kind == "door"
            and string.format("Door verifier stand %d,%d", state.origin_x, state.origin_y)
            or string.format("Walked verifier origin %d,%d", state.origin_x, state.origin_y),
        type = "coordinate",
        x = state.origin_x,
        y = state.origin_y,
    }
    local plan = route_to(target, {
        path_mode = "direct",
        allow_adjacent_fallback = false,
        post_arrival_actions = false,
        speak = true,
    }) or {}
    local status = tostring(plan.status or (plan.ok and "queued" or "unknown"))
    local path_len = tonumber(plan.path_length) or (plan.path and #plan.path) or 0
    local prefix = state.kind == "door" and "DOOR_VERIFY_ROUTE" or "WALKED_EDGE_VERIFY_ROUTE"
    self:_info(string.format(
        "%s map=%s origin=(%d,%d) dir=%s dest=(%d,%d) status=%s path_len=%d",
        prefix,
        format_map_id(state.map_id),
        state.origin_x,
        state.origin_y,
        state.dir,
        state.dest_x,
        state.dest_y,
        status,
        path_len))
    if status == "queued" or plan.ok == true then
        self.pending = state
        return true
    end
    self:_abort_pending_state(state, "route_failed:" .. status)
    return false, status
end

function Controller:_abort_pending_state(state, reason)
    if not state then
        return
    end
    local _, px, py = self:_position()
    local prefix = state.kind == "door" and "DOOR_VERIFY_ABORT" or "WALKED_EDGE_VERIFY_ABORT"
    self:_info(string.format(
        "%s map=%s origin=(%d,%d) dir=%s dest=(%d,%d) current=(%d,%d) reason=%s",
        prefix,
        format_map_id(state.map_id),
        state.origin_x,
        state.origin_y,
        tostring(state.dir),
        state.dest_x,
        state.dest_y,
        px or -1,
        py or -1,
        tostring(reason)))
    if self.pending == state then
        self.pending = nil
    end
end

function Controller:_start_probe_from_state(state)
    local start_probe = self.deps.start_probe
    if not start_probe then
        self:_abort_pending_state(state, "probe_unavailable")
        return false
    end
    local ok, reason = start_probe(state.dir, "walked_edge_verify")
    if ok == false then
        self:_abort_pending_state(state, "probe_failed:" .. tostring(reason))
        return false
    end
    self:_info(string.format(
        "WALKED_EDGE_VERIFY_PROBE map=%s origin=(%d,%d) dir=%s dest=(%d,%d) source=walked_route",
        format_map_id(state.map_id),
        state.origin_x,
        state.origin_y,
        state.dir,
        state.dest_x,
        state.dest_y))
    self.pending = nil
    self:_speak("Walked edge origin reached. Probe started.")
    return true
end

function Controller:_mark_door_ready(state)
    local baseline = self:_door_snapshot()
    state.baseline = baseline
    self.pending = nil
    self.door_state = state
    self:_info(string.format(
        "DOOR_VERIFY_READY map=%s stand=(%d,%d) dir=%s expected_door=(%d,%d) keys_before=%s baseline_slots=%s action=manual_open_then_verify_door_after",
        format_map_id(state.map_id),
        state.origin_x,
        state.origin_y,
        state.dir,
        state.dest_x,
        state.dest_y,
        tostring(baseline.keys),
        format_slots(baseline)))
    self:_speak("Door verifier ready. Use OPEN, then run verify door after.")
    return true
end

function Controller:start_edge(arg)
    if self.pending then
        self:_error("verify_walked_edge: another walked verifier route is pending")
        return false
    end
    local map_id, px, py = self:_position()
    local x, y, dir = parse_edge_arg(arg, self.deps.dir_to_delta, px, py)
    if x == nil then
        self:_error("verify_walked_edge usage: verify_walked_edge:DIR or verify_walked_edge:X,Y,DIR")
        return false
    end
    local delta = self.deps.dir_to_delta[dir]
    local state = {
        kind = "edge",
        map_id = map_id,
        origin_x = x,
        origin_y = y,
        dir = dir,
        dest_x = x + delta.dx,
        dest_y = y + delta.dy,
        phase = "routing",
    }
    self:_info(string.format(
        "WALKED_EDGE_VERIFY_START map=%s current=(%d,%d) origin=(%d,%d) dir=%s dest=(%d,%d) mode=walked",
        format_map_id(map_id),
        px or -1,
        py or -1,
        x,
        y,
        dir,
        state.dest_x,
        state.dest_y))
    if px == x and py == y then
        self:_info(string.format(
            "WALKED_EDGE_VERIFY_ROUTE map=%s origin=(%d,%d) dir=%s dest=(%d,%d) status=already_at_origin origin_status=already_at_origin path_len=0",
            format_map_id(map_id),
            x,
            y,
            dir,
            state.dest_x,
            state.dest_y))
        return self:_start_probe_from_state(state)
    end
    return self:_route_to_origin(state)
end

function Controller:start_door_stand(arg)
    if self.pending then
        self:_error("verify_door_stand: another walked verifier route is pending")
        return false
    end
    if self.door_state then
        self:_error("verify_door_stand: finish or cancel the active door verification first")
        return false
    end
    local map_id, px, py = self:_position()
    local x, y, dir = parse_stand_arg(arg, self.deps.dir_to_delta)
    if x == nil then
        self:_error("verify_door_stand usage: verify_door_stand:X,Y,DIR")
        return false
    end
    local delta = self.deps.dir_to_delta[dir]
    local state = {
        kind = "door",
        map_id = map_id,
        origin_x = x,
        origin_y = y,
        dir = dir,
        dest_x = x + delta.dx,
        dest_y = y + delta.dy,
        phase = "routing",
    }
    self:_info(string.format(
        "DOOR_VERIFY_START map=%s current=(%d,%d) stand=(%d,%d) dir=%s expected_door=(%d,%d) mode=walked_manual_open",
        format_map_id(map_id),
        px or -1,
        py or -1,
        x,
        y,
        dir,
        state.dest_x,
        state.dest_y))
    if px == x and py == y then
        self:_info(string.format(
            "DOOR_VERIFY_ROUTE map=%s origin=(%d,%d) dir=%s dest=(%d,%d) status=already_at_origin origin_status=already_at_origin path_len=0",
            format_map_id(map_id),
            x,
            y,
            dir,
            state.dest_x,
            state.dest_y))
        return self:_mark_door_ready(state)
    end
    return self:_route_to_origin(state)
end

function Controller:on_route_completed()
    local state = self.pending
    if not state then
        return false
    end
    local map_id, px, py = self:_position()
    if map_id ~= state.map_id then
        self:_abort_pending_state(state, "route_completed_map_changed")
        return false
    end
    if px ~= state.origin_x or py ~= state.origin_y then
        self:_abort_pending_state(state, "route_completed_wrong_origin")
        return false
    end
    if state.kind == "door" then
        return self:_mark_door_ready(state)
    end
    state.phase = "ready_to_probe"
    self:_info(string.format(
        "WALKED_EDGE_VERIFY_ROUTE_READY map=%s origin=(%d,%d) dir=%s dest=(%d,%d) status=route_completed",
        format_map_id(state.map_id),
        state.origin_x,
        state.origin_y,
        state.dir,
        state.dest_x,
        state.dest_y))
    return true
end

function Controller:on_route_cancelled(data)
    local state = self.pending
    if not state then
        return false
    end
    local reason = data and data.reason or "unknown"
    if reason == "route_drift_off_path" then
        self:_info(string.format(
            "%s map=%s origin=(%d,%d) dir=%s dest=(%d,%d) reason=route_drift_off_path action=wait_for_reroute",
            state.kind == "door" and "DOOR_VERIFY_ROUTE_WAIT" or "WALKED_EDGE_VERIFY_ROUTE_WAIT",
            format_map_id(state.map_id),
            state.origin_x,
            state.origin_y,
            tostring(state.dir),
            state.dest_x,
            state.dest_y))
        return true
    end
    self:_abort_pending_state(state, "route_cancelled:" .. tostring(reason))
    return true
end

function Controller:tick()
    local state = self.pending
    if not state or state.phase ~= "ready_to_probe" then
        return false
    end
    return self:_start_probe_from_state(state)
end

function Controller:finish_door_after()
    local state = self.door_state
    if not state then
        self:_error("verify_door_after: no active door verification")
        return false
    end
    local after = self:_door_snapshot()
    local before_keys = tonumber(state.baseline and state.baseline.keys)
    local after_keys = tonumber(after.keys)
    local key_delta = 0
    if before_keys and after_keys then
        key_delta = before_keys - after_keys
    end
    local expected_present = snapshot_contains(after, state.dest_x, state.dest_y)
    self:_info(string.format(
        "DOOR_VERIFY_RESULT map=%s stand=(%d,%d) dir=%s expected_door=(%d,%d) expected_present=%s keys_before=%s keys_after=%s key_delta=%d before_slots=%s after_slots=%s",
        format_map_id(state.map_id),
        state.origin_x,
        state.origin_y,
        state.dir,
        state.dest_x,
        state.dest_y,
        tostring(expected_present),
        tostring(state.baseline and state.baseline.keys),
        tostring(after.keys),
        key_delta,
        format_slots(state.baseline),
        format_slots(after)))
    self.door_state = nil
    if expected_present then
        self:_speak("Door verification recorded the expected opened door.")
    else
        self:_speak("Door verification did not find the expected opened door.")
    end
    return true
end

function Controller:cancel_edge(reason)
    local state = self.pending
    if not state or state.kind ~= "edge" then
        self:_error("stop_verify_walked_edge: no active walked edge verification")
        return false
    end
    local stop_reason = reason or "manual_stop"
    self:_stop_route(stop_reason)
    self:_abort_pending_state(state, stop_reason)
    return true
end

function Controller:cancel_door(reason)
    if self.pending and self.pending.kind == "door" then
        local stop_reason = reason or "manual_stop"
        self:_stop_route(stop_reason)
        self:_abort_pending_state(self.pending, stop_reason)
        return true
    end
    if self.door_state then
        self:_info(string.format(
            "DOOR_VERIFY_ABORT map=%s origin=(%d,%d) dir=%s dest=(%d,%d) current=(-1,-1) reason=%s",
            format_map_id(self.door_state.map_id),
            self.door_state.origin_x,
            self.door_state.origin_y,
            tostring(self.door_state.dir),
            self.door_state.dest_x,
            self.door_state.dest_y,
            tostring(reason or "manual_stop")))
        self.door_state = nil
        return true
    end
    self:_error("stop_verify_door: no active door verification")
    return false
end

function Controller:has_pending_route()
    return self.pending ~= nil
end

function Controller:has_pending_edge()
    return self.pending ~= nil and self.pending.kind == "edge"
end

function Controller:has_pending_door()
    return self.pending ~= nil and self.pending.kind == "door"
end

function Controller:has_active_door()
    return self.door_state ~= nil or (self.pending ~= nil and self.pending.kind == "door")
end

return M
