-- object_commands.lua
-- Debug-command registration for object browsing and object-route actions.

local debug_tools = require "debug_tools"
local objects = require "objects"
local route_mgr = require "route_manager"
local tolk = require "tolk"

local M = {}

local function refresh_pathability_if_needed()
    if route_mgr.refresh_object_pathability_filter_if_needed then
        route_mgr.refresh_object_pathability_filter_if_needed()
    end
end

local function describe_selected(opts)
    refresh_pathability_if_needed()
    return route_mgr.describe_current_object(opts)
end

local function speak_filter(prefix, opts)
    refresh_pathability_if_needed()
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

function M.register()
    debug_tools.register_command("next_object", function()
        refresh_pathability_if_needed()
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
        refresh_pathability_if_needed()
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
        refresh_pathability_if_needed()
        route_mgr.pathfind_to_current()
    end)

    debug_tools.register_command("auto_walk", function()
        refresh_pathability_if_needed()
        route_mgr.autowalk_to_current()
    end)
end

return M
