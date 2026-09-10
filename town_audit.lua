-- town_audit.lua
-- Read-only, frame-budgeted town route inventory. Every result is a model
-- prediction tied to one snapshot, never proof of live arrival or interaction.
local M = {}
local Controller = {}
Controller.__index = Controller
local script_dir = debug.getinfo(1, "S").source:match("@?(.*[\\/])") or ""
local TOWNS = {[3]=true, [4]=true, [5]=true, [7]=true, [8]=true, [9]=true, [10]=true, [11]=true}
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = copy(v) end
    return out
end
local function key(x, y) return x .. "," .. y end
local function quote(value)
    return '"' .. tostring(value):gsub('[%z\1-\31\\"]', function(c)
        if c == '"' then return '\\"' end
        if c == "\\" then return "\\\\" end
        return string.format("\\u%04x", c:byte())
    end) .. '"'
end
local function json(value)
    local kind = type(value)
    if kind == "nil" then return "null" end
    if kind == "boolean" or kind == "number" then return tostring(value) end
    if kind == "string" then return quote(value) end
    assert(kind == "table", "Unsupported audit JSON value")
    local keys, array = {}, true
    for k in pairs(value) do
        keys[#keys + 1] = k
        if type(k) ~= "number" or k < 1 or k > #value or k % 1 ~= 0 then array = false end
    end
    local parts = {}
    if array then
        for _, v in ipairs(value) do parts[#parts + 1] = json(v) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do parts[#parts + 1] = quote(k) .. ":" .. json(value[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
end
local function fingerprint(value)
    local text = type(value) == "string" and value or json(value)
    local hash = 0
    for i = 1, #text do hash = (hash * 31 + text:byte(i)) % 2147483647 end
    return string.format("%08x", hash)
end
local function clean(value) return tostring(value or "-"):gsub("[\r\n\t]", " ") end
local function priority(obj)
    if obj.service then return 1 end
    if obj.type == "exit" or obj.type == "stair" then return 2 end
    if obj.type == "npc" then return 3 end
    return 4
end
local function summary(report)
    local c = report.counts
    return string.format("Town audit %s for %s at (%d,%d): %d of %d targets. %d modeled reachable, %d NPC obstructed, %d model blocked, %d return concerns. Live access untested.",
        report.status, report.map_name, report.start.x, report.start.y, #report.rows, report.total,
        c.modeled_reachable, c.npc_obstructed, c.model_blocked, c.return_concerns)
end
local function text_report(report)
    local lines = {summary(report), "Snapshot: " .. report.created_at .. "; fingerprint: " .. report.fingerprint,
        "NPC positions and doors were captured at audit start. No movement, TALK, or map edits performed.",
        "A modeled route does not establish live access. Frontier groups are investigation candidates.",
        "Return checks use the selected modeled approach spot; map transitions are not tested.",
        "Return destination: " .. (report.return_mode == "adjacent" and "in-town approach to the starting exit/stair"
            or report.return_mode == "unmodeled_anchor" and "unmodeled starting tile; return check unavailable"
            or "original starting tile"), ""}
    if report.reason then lines[#lines + 1] = "Stopped: " .. clean(report.reason) end
    for _, row in ipairs(report.rows) do
        local function route_text(plan)
            if not plan.reachable then return "no route" end
            return string.format("%d steps to (%d,%d), face %s", plan.steps, plan.stand.x, plan.stand.y, plan.face_dir or "-")
        end
        lines[#lines + 1] = string.format("%s [%s] %s; %s", clean(row.name), row.id, row.role, row.classification)
        lines[#lines + 1] = "  With NPCs: " .. route_text(row.with_npcs) .. "; without NPCs: " .. route_text(row.without_npcs)
        lines[#lines + 1] = "  Return: " .. row.return_route.status .. "; live arrival / interaction / return: untested"
        for _, f in ipairs(row.frontiers) do
            lines[#lines + 1] = string.format("  Candidate %s: (%d,%d) %s -> (%d,%d), %s, connects target side=%s, hidden bridge=%s",
                f.group, f.from_x, f.from_y, f.dir, f.dest_x, f.dest_y, f.reason .. "/" .. (f.walk_reason or "unknown"),
                tostring(f.bridge_to_target), tostring(f.hidden_bridge_to_target))
        end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Shared frontier groups (candidates, not confirmed blockers):"
    for _, group in ipairs(report.groups) do
        lines[#lines + 1] = group.id .. ": " .. table.concat(group.targets, ", ")
    end
    return table.concat(lines, "\n") .. "\n"
end
local function write_file(path, content)
    local f, err = io.open(path, "wb")
    if not f then return nil, err end
    local ok, write_err = f:write(content)
    local closed, close_err = f:close()
    if not ok or not closed then return nil, write_err or close_err end
    return true
end
function M.save_report(report, directory)
    directory = directory or script_dir
    local base = directory .. string.format("town_audit_%02x_%s", report.map_id, report.created_at:gsub("[^%w]", ""))
    local index = 1
    while true do
        local candidate = base .. string.format("_%03d", index)
        local f = io.open(candidate .. ".json", "rb")
        local t = io.open(candidate .. ".txt", "rb")
        if f then f:close() end
        if t then t:close() end
        if not f and not t then base = candidate; break end
        index = index + 1
    end
    local ok, err = write_file(base .. ".json", json(report) .. "\n")
    if not ok then return nil, "JSON save failed: " .. tostring(err) end
    ok, err = write_file(base .. ".txt", text_report(report))
    if not ok then return nil, "Text save failed: " .. tostring(err) .. "; JSON saved at " .. base .. ".json" end
    return {json = base .. ".json", text = base .. ".txt"}
end
function M.new(deps) return setmetatable({deps = deps}, Controller) end
function Controller:start(scope)
    scope = tostring(scope or "all"):match("^%s*(.-)%s*$"):lower()
    if scope == "" then scope = "all" end
    if scope ~= "all" and scope ~= "services" then return false, "Use audit_town or audit_town:services" end
    if self.active then return false, "Town audit already running" end
    local captured, ctx, err = pcall(self.deps.capture, scope)
    if not captured then return false, "Town audit snapshot failed: " .. tostring(ctx) end
    if not ctx then return false, err end
    table.sort(ctx.targets, function(a,b)
        if priority(a) ~= priority(b) then return priority(a) < priority(b) end
        return tostring(a.id) < tostring(b.id)
    end)
    self.context = ctx
    self.result = {schema_version = 1, kind = "modeled_town_audit", status = "running", scope = scope,
        map_id = ctx.map_id, map_name = ctx.map_name, start = {x = ctx.x, y = ctx.y},
        created_at = self.deps.now(), fingerprint = fingerprint(ctx.evidence), snapshot = ctx.evidence,
        return_mode = ctx.return_mode or "direct",
        total = #ctx.targets, rows = {}, groups = {},
        counts = {modeled_reachable = 0, npc_obstructed = 0, model_blocked = 0, return_concerns = 0}}
    self.paths, self.save_error = nil, nil
    self.active = true
    self.group_index = {}
    return true, "Town audit started for " .. ctx.map_name .. ". Stand still while the report is prepared."
end
local function pack_plan(plan, ctx)
    local out = {reachable = plan and plan.reachable == true, reason = plan and plan.no_path_reason,
        path_mode = plan and plan.path_mode, goal_x = plan and plan.goal_x, goal_y = plan and plan.goal_y}
    if out.reachable then
        local path = plan.path or {}
        local last = path[#path]
        out.stand = {x = last and last.x or ctx.x, y = last and last.y or ctx.y}
        out.steps = #path
        out.face_dir = plan.face_dir or (plan.selected_interaction and plan.selected_interaction.face_dir)
        if not out.face_dir and plan.path_mode == "adjacent" and plan.goal_x and plan.goal_y then
            if plan.goal_y < out.stand.y then out.face_dir = "north"
            elseif plan.goal_y > out.stand.y then out.face_dir = "south"
            elseif plan.goal_x < out.stand.x then out.face_dir = "west"
            elseif plan.goal_x > out.stand.x then out.face_dir = "east" end
        end
    end
    return out
end
local function frontier_goals(obj, plan)
    local goals = {}
    if obj.interaction_x and obj.interaction_y then goals[#goals+1] = {x=obj.interaction_x, y=obj.interaction_y} end
    for _, p in ipairs(obj.interaction_points or {}) do
        goals[#goals+1] = {x=p.x or p.interaction_x, y=p.y or p.interaction_y}
    end
    if #goals == 0 then
        local x, y = plan.goal_x or obj.x, plan.goal_y or obj.y
        if plan.path_mode == "adjacent" then
            goals = {{x=x,y=y-1}, {x=x,y=y+1}, {x=x-1,y=y}, {x=x+1,y=y}}
        else goals = {{x=x,y=y}} end
    end
    return goals
end
function Controller:audit_target(obj)
    local ctx = self.context
    local with_npcs = pack_plan(self.deps.plan(ctx, obj, false), ctx)
    local without_npcs = pack_plan(self.deps.plan(ctx, obj, true), ctx)
    local class = with_npcs.reachable and "modeled_reachable"
        or (without_npcs.reachable and "npc_obstructed" or "model_blocked")
    local row = {id = obj.id, name = obj.name, role = obj.service and "service" or obj.type,
        object = copy(obj), classification = class, with_npcs = with_npcs, without_npcs = without_npcs,
        live_arrival = "untested", live_interaction = "untested", live_return = "untested", frontiers = {}}
    local chosen = with_npcs.reachable and with_npcs or without_npcs
    if not chosen.reachable then row.return_route = {status = "outward_unreachable"}
    elseif obj.type == "exit" or obj.type == "stair" then
        row.return_route = {status = "transition_not_tested"}
    elseif ctx.return_mode == "unmodeled_anchor" then
        row.return_route = {status = "anchor_unmodeled"}
    else
        local with_return = self.deps.return_path(ctx, chosen.stand, false)
        local without_return = self.deps.return_path(ctx, chosen.stand, true)
        local return_status = with_return and "modeled_reachable"
            or (without_return and "npc_obstructed" or "model_blocked")
        row.return_route = {status = return_status, from = chosen.stand,
            with_npcs = with_return ~= nil, without_npcs = without_return ~= nil,
            destination_mode = ctx.return_mode or "direct",
            with_npcs_steps = with_return and #with_return, without_npcs_steps = without_return and #without_return,
            with_npcs_destination = with_return and (with_return[#with_return] or chosen.stand),
            without_npcs_destination = without_return and (without_return[#without_return] or chosen.stand)}
        if return_status ~= "modeled_reachable" then self.result.counts.return_concerns = self.result.counts.return_concerns + 1 end
    end
    -- Only failed map routes need costly frontier ranking. Do not mistake a
    -- crowd for a static map defect or use the NPC tile as a counter goal.
    if class == "model_blocked" then
        local analysis = self.deps.frontier(ctx, obj, frontier_goals(obj, without_npcs))
        for i = 1, math.min(3, #(analysis and analysis.frontiers or {})) do
            local f = copy(analysis.frontiers[i])
            f.group = string.format("%02x:%d,%d:%s", ctx.map_id, f.dest_x, f.dest_y, f.approach)
            row.frontiers[#row.frontiers+1] = f
            local group = self.group_index[f.group]
            if not group then
                group = {id = f.group, targets = {}, reason = f.reason}
                self.group_index[f.group] = group
                self.result.groups[#self.result.groups+1] = group
            end
            group.targets[#group.targets+1] = obj.id
        end
    end
    self.result.counts[class] = self.result.counts[class] + 1
    self.result.rows[#self.result.rows+1] = row
end
function Controller:finish(status, reason)
    self.active = false
    local r = self.result
    r.status, r.reason = status, reason
    table.sort(r.groups, function(a,b)
        if #a.targets ~= #b.targets then return #a.targets > #b.targets end
        return a.id < b.id
    end)
    local saved, paths, err = pcall(self.deps.save, r)
    if not saved then err, paths = paths, nil end
    if paths then self.paths = paths else self.save_error = tostring(err) end
    local message = summary(r)
    if paths then message = message .. " Report saved."
    else message = message .. " Report save failed: " .. self.save_error end
    self.deps.log("TOWN_AUDIT_FINISH: " .. message)
    if paths then self.deps.log("TOWN_AUDIT_FILES json=" .. paths.json .. " text=" .. paths.text) end
    self.deps.speak(message)
    return message
end
function Controller:tick(can_walk)
    if not self.active then return end
    local ok, err = pcall(function()
        local changed = self.deps.changed(self.context, can_walk)
        if changed then self:finish("aborted", changed); return end
        local next_obj = self.context.targets[#self.result.rows + 1]
        if next_obj then self:audit_target(next_obj) end
        if #self.result.rows == self.result.total then self:finish("complete") end
    end)
    if not ok and self.active then self:finish("error", tostring(err)) end
end
function Controller:stop()
    if not self.active then return "No town audit is running" end
    return self:finish("stopped", "user_requested")
end
function Controller:report()
    if not self.result then return "No town audit in this script session. Saved report files remain on disk." end
    local message = summary(self.result)
    if self.paths then message = message .. " Text report: " .. self.paths.text end
    if self.save_error then message = message .. " Save failed: " .. self.save_error end
    self.deps.log("TOWN_AUDIT_STATUS: " .. message)
    return message
end

local function runtime_deps()
    local objects, reader, routes = require "objects", require "map_reader", require "route_manager"
    local nav, snapshot, addr = require "navigation", require "game_snapshot", require "addresses"
    local debug_tools = require "debug_tools"
    local function doors()
        local result = {}
        for i=0, addr.DOOR_ARRAY_MAX-1 do
            result[#result+1] = {x=memory.readbyte(addr.DOOR_X_POS_START+i*addr.DOOR_ARRAY_STRIDE),
                y=memory.readbyte(addr.DOOR_Y_POS_START+i*addr.DOOR_ARRAY_STRIDE)}
        end
        return result
    end
    local function guard()
        if _G.DW_FIELD_ACTION_UNAVAILABLE_REASON then
            return _G.DW_FIELD_ACTION_UNAVAILABLE_REASON("object_controls")
        end
        return "Town audit requires the normal gameplay loop"
    end
    local function sources()
        local out = {}
        for _, name in ipairs({"map_reader.lua", "objects.lua", "route_manager.lua", "pathfinder.lua", "route_frontier.lua"}) do
            local f = io.open(script_dir .. name, "rb")
            if f then out[name] = fingerprint(f:read("*a")); f:close() end
        end
        return out
    end
    return {
        now = function() return os.date("!%Y-%m-%dT%H:%M:%SZ") end,
        log = debug_tools.info, speak = require("tolk").output_interrupt,
        save = function(r) return M.save_report(r) end,
        capture = function(scope)
            local refusal = guard()
            if refusal then return nil, refusal end
            local map_id, x, y = nav.get_position()
            if not TOWNS[map_id] then return nil, "Town audit is available in towns and Tantegel only" end
            objects.check_refresh(map_id)
            if objects.needs_refresh(map_id) then return nil, "Town objects are still loading. Try again in a moment." end
            objects.update_npcs()
            local width, height = reader.get_map_dimensions(map_id)
            local walkability = reader.get_walkability_snapshot(map_id)
            if not width or not height or not walkability then return nil, "Town map data unavailable" end
            local targets, transition_anchor = {}, false
            for _, obj in ipairs(objects.get_objects({visible=true})) do
                if (obj.type == "exit" or obj.type == "stair") and obj.x == x and obj.y == y then
                    transition_anchor = true
                end
                if scope == "all" or obj.service then targets[#targets+1] = copy(obj) end
            end
            local details = {}
            for cy=0,height-1 do
                for cx=0,width-1 do details[key(cx,cy)] = copy(reader.get_walkability_details(map_id,cx,cy)) end
            end
            local ctx = {map_id=map_id, map_name=require("maps").get_name(map_id), x=x, y=y, targets=targets,
                width=width, height=height, walkability=walkability, details=details,
                with_npcs=copy(routes.build_path_blocking(map_id)),
                without_npcs=copy(routes.build_path_blocking(map_id,{skip_npcs=true})),
                directional=copy(reader.get_directional_blocks(map_id)),
                door_token=json(doors()), terrain=snapshot.terrain_offset}
            local runtime = {}
            for cy=0,height-1 do
                for cx=0,width-1 do runtime[key(cx,cy)] = copy(routes.is_cell_runtime_blocked(map_id,cx,cy)) end
            end
            ctx.return_mode = transition_anchor and "adjacent"
                or (walkability[y] and walkability[y][x] == true and "direct" or "unmodeled_anchor")
            ctx.runtime = runtime
            ctx.evidence = {width=width, height=height, raw_tiles=copy(reader.get_tile_grid(map_id)),
                walkability=copy(walkability), directional_blocks=ctx.directional, runtime_blocks=runtime,
                npc_positions=copy(objects.get_blocking_positions()), doors=doors(), keys=snapshot.keys,
                terrain=ctx.terrain, targets=targets, model_source_checksums=sources(),
                anchor={x=x,y=y,return_mode=ctx.return_mode}, hazards_allowed=false, npc_policy="captured_positions"}
            return ctx
        end,
        changed = function(ctx, can_walk)
            if can_walk == false then return "field_control_changed" end
            local refusal = guard()
            if refusal then return refusal end
            local map_id,x,y = nav.get_position()
            if map_id ~= ctx.map_id or x ~= ctx.x or y ~= ctx.y then return "hero_position_changed" end
            if snapshot.terrain_offset ~= ctx.terrain or json(doors()) ~= ctx.door_token then return "map_or_door_state_changed" end
            if package.loaded.objects ~= objects or package.loaded.map_reader ~= reader then return "navigation_modules_reloaded" end
        end,
        plan = function(ctx, obj, skip_npcs)
            return routes.object_reachability(obj, {map_id=ctx.map_id, start_x=ctx.x, start_y=ctx.y,
                blocking=skip_npcs and ctx.without_npcs or ctx.with_npcs,
                skip_npcs=skip_npcs, walkability_snapshot=ctx.walkability, respect_darkness=true})
        end,
        return_path = function(ctx, stand, skip_npcs)
            local plan = routes.object_reachability({name="Audit origin", type="exit", x=ctx.x, y=ctx.y}, {
                map_id=ctx.map_id, start_x=stand.x, start_y=stand.y, path_mode=ctx.return_mode,
                blocking=skip_npcs and ctx.without_npcs or ctx.with_npcs,
                skip_npcs=skip_npcs, walkability_snapshot=ctx.walkability, respect_darkness=true})
            return plan and plan.reachable and (plan.path or {}) or nil
        end,
        frontier = function(ctx, obj, goals)
            return require("route_frontier").analyze({map_id=ctx.map_id, start_x=ctx.x, start_y=ctx.y,
                goal_x=goals[1].x, goal_y=goals[1].y, goal_points=goals, walkability=ctx.walkability,
                blocking=ctx.without_npcs,
                map_reader={get_map_dimensions=function() return ctx.width,ctx.height end,
                    get_directional_blocks=function() return ctx.directional end,
                    get_walkability_details=function(_,x,y) return ctx.details[key(x,y)] end},
                route_manager={is_cell_runtime_blocked=function(_,x,y) return ctx.runtime[key(x,y)] end}})
        end,
    }
end
local current
function M.start(scope)
    if current and current.active then return false, "Town audit already running" end
    local controller = M.new(runtime_deps())
    local ok, message = controller:start(scope)
    if ok then current = controller end
    return ok, message
end
function M.tick(can_walk) if current then current:tick(can_walk) end end
function M.report() return current and current:report() or "No town audit in this script session. Saved report files remain on disk." end
function M.stop() return current and current:stop() or "No town audit is running" end
return M
