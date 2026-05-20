-- object_commands.lua
-- Debug-command registration for object browsing and object-route actions.

local debug_tools = require "debug_tools"
local nav = require "navigation"
local objects = require "objects"
local overworld_routes = require "overworld_routes"
local route_mgr = require "route_manager"
local tolk = require "tolk"
local snapshot = require "game_snapshot"

local M = {}

local function refresh_pathability_if_needed()
    if route_mgr.refresh_object_pathability_filter_if_needed then
        route_mgr.refresh_object_pathability_filter_if_needed()
    end
end

local function refresh_live_objects_for_browse()
    if objects.update_npcs then
        objects.update_npcs()
    end
end

local function refresh_object_browser_context(opts)
    opts = opts or {}
    if opts.refresh_live_npcs == true then
        refresh_live_objects_for_browse()
    end
    refresh_pathability_if_needed()
end

local function describe_selected(opts)
    refresh_object_browser_context()
    return route_mgr.describe_current_object(opts)
end

local function speak_filter(prefix, opts)
    refresh_object_browser_context()
    local count = objects.get_count()
    local label = objects.get_filter_summary and objects.get_filter_summary() or prefix
    if count > 0 then
        local desc = label .. ". " .. route_mgr.describe_current_object(opts)
        debug_tools.info("FILTER: " .. desc)
        tolk.output_interrupt(desc)
    else
        local desc = label .. ". No objects"
        debug_tools.info("FILTER: " .. desc)
        tolk.output_interrupt(desc)
    end
end

local function speak_pathability_result(info)
    info = info or {
        name = objects.get_filter_summary and objects.get_filter_summary() or objects.get_filter_name(),
        count = objects.get_count(),
    }

    if info.unavailable then
        local msg = "Reachability filter unavailable here. " .. info.name
        debug_tools.info("PATHABILITY_FILTER: " .. msg)
        tolk.output_interrupt(msg)
        return
    end

    if (info.count or objects.get_count()) > 0 then
        local desc = info.name .. ". " .. route_mgr.describe_current_object({
            include_reachability = false,
            include_debug_coords = false,
        })
        debug_tools.info("PATHABILITY_FILTER: " .. desc)
        tolk.output_interrupt(desc)
    else
        local desc = info.name .. ". No objects"
        debug_tools.info("PATHABILITY_FILTER: " .. desc)
        tolk.output_interrupt(desc)
    end
end

local function current_position()
    local map_id, x, y = nav.get_position()
    return map_id, x, y, snapshot.terrain_offset
end

local function speak_route_event(prefix, info)
    if not info then
        return
    end
    debug_tools.info(prefix .. ": " .. tostring(info.log or info.message))
    if info.refresh and objects.request_refresh then
        objects.request_refresh()
    end
    tolk.output_interrupt(info.message)
end

function M.register()
    debug_tools.register_command("next_object", function()
        refresh_object_browser_context()
        local obj = objects.next_object()
        if obj then
            local desc = route_mgr.describe_current_object()
            debug_tools.info("OBJECT: " .. desc)
            tolk.output_interrupt(desc)
        else
            debug_tools.info("OBJECT: No objects found")
            tolk.output_interrupt("No objects found")
        end
    end)

    debug_tools.register_command("prev_object", function()
        refresh_object_browser_context()
        local obj = objects.prev_object()
        if obj then
            local desc = route_mgr.describe_current_object()
            debug_tools.info("OBJECT: " .. desc)
            tolk.output_interrupt(desc)
        else
            debug_tools.info("OBJECT: No objects found")
            tolk.output_interrupt("No objects found")
        end
    end)

    debug_tools.register_command("current_object", function()
        local desc = describe_selected()
        debug_tools.info("OBJECT: " .. desc)
        tolk.output_interrupt(desc)
    end)

    debug_tools.register_command("next_filter", function()
        objects.next_filter()
        speak_filter(objects.get_filter_name())
    end)

    debug_tools.register_command("prev_filter", function()
        objects.prev_filter()
        speak_filter(objects.get_filter_name())
    end)

    debug_tools.register_command("pathability_filter", function(arg)
        local scope = (arg and arg:match("^%s*(.-)%s*$")) or ""
        local info, err
        refresh_live_objects_for_browse()
        if scope == "" then
            info, err = route_mgr.next_object_pathability_filter()
        elseif scope:lower() == "refresh" then
            info = route_mgr.refresh_object_pathability_filter({force = true})
        else
            info, err = route_mgr.set_object_pathability_filter(scope)
        end
        if not info then
            debug_tools.error(err)
            tolk.output_interrupt(err)
            return
        end
        speak_pathability_result(info)
    end)

    debug_tools.register_command("mark_visited", function()
        local obj = objects.mark_current_visited()
        if obj then
            local msg = obj.name .. " marked visited"
            debug_tools.info("VISITED_MANUAL target_id=" .. tostring(obj.id) .. " target_name=" .. tostring(obj.name))
            tolk.output_interrupt(msg)
        else
            debug_tools.info("VISITED_MANUAL no object selected")
            tolk.output_interrupt("No object selected")
        end
    end)

    debug_tools.register_command("clear_visited", function(arg)
        local scope = (arg and arg:match("^%s*(.-)%s*$")) or ""
        local cleared
        local msg
        if scope == "all" then
            cleared = objects.clear_visited("all")
            msg = string.format("Cleared %d visited flags for all maps", cleared)
        else
            cleared = objects.clear_visited()
            msg = string.format("Cleared %d visited flags for this map", cleared)
        end
        debug_tools.info("VISITED_CLEAR " .. msg)
        tolk.output_interrupt(msg)
    end)

    debug_tools.register_command("pathfind", function()
        refresh_object_browser_context({refresh_live_npcs = true})
        route_mgr.pathfind_to_current()
    end)

    debug_tools.register_command("auto_walk", function()
        refresh_object_browser_context({refresh_live_npcs = true})
        route_mgr.autowalk_to_current()
    end)

    debug_tools.register_command("start_overworld_route", function(arg)
        local map_id, x, y, terrain_offset = current_position()
        local info, err = overworld_routes.start(arg, map_id, x, y, {
            terrain_offset = terrain_offset,
        })
        if not info then
            debug_tools.error("OVERWORLD_ROUTE: " .. tostring(err))
            tolk.output_interrupt(tostring(err))
            return
        end
        speak_route_event("OVERWORLD_ROUTE", info)
    end)

    debug_tools.register_command("route_guidance", function()
        local map_id, x, y, terrain_offset = current_position()
        local info, err = overworld_routes.guidance_for_object(objects.current_object(), map_id, x, y, {
            terrain_offset = terrain_offset,
        })
        if not info then
            debug_tools.info("OVERWORLD_ROUTE: event=no_route message=" .. tostring(err))
            tolk.output_interrupt(tostring(err))
            return
        end
        speak_route_event("OVERWORLD_ROUTE", info)
    end)

    local function recalculate_route_command()
        local map_id, x, y, terrain_offset = current_position()
        local info = overworld_routes.recalculate(map_id, x, y, {
            terrain_offset = terrain_offset,
        })
        speak_route_event("OVERWORLD_ROUTE", info)
    end

    debug_tools.register_command("route_recalculate", recalculate_route_command)
    debug_tools.register_command("recalculate_overworld_route", recalculate_route_command)

    debug_tools.register_command("route_status", function()
        local map_id, x, y, terrain_offset = current_position()
        speak_route_event("OVERWORLD_ROUTE", overworld_routes.status(map_id, x, y, {
            terrain_offset = terrain_offset,
        }))
    end)

    debug_tools.register_command("stop_overworld_route", function()
        speak_route_event("OVERWORLD_ROUTE", overworld_routes.stop())
    end)
end

return M
