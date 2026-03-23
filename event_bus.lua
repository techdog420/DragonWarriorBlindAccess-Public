-- event_bus.lua
-- Lightweight publish/subscribe event system.
--
-- Decouples game modules by letting producers publish named events and
-- consumers subscribe handlers without either side knowing about the other.
-- This replaces direct callback assignments (e.g. auto_step.on_blocked = fn)
-- and explicit hook calls (e.g. debug_tools.on_menu_open()) with a single
-- shared messaging channel.
--
-- Usage:
--   local event_bus = require "event_bus"
--
--   -- Subscribe a handler (returns a handle for unsubscribe)
--   local handle = event_bus.subscribe("battle_started", function(data)
--       print("Battle! Enemy: " .. data.enemy_type)
--   end)
--
--   -- Publish an event (all subscribers are called with the data table)
--   event_bus.publish("battle_started", {enemy_type = "Slime"})
--
--   -- Unsubscribe when no longer needed
--   event_bus.unsubscribe(handle)
--
-- Design notes:
--   - Handlers are called in subscription order via pcall for safety.
--     A failing handler logs an error but does not break other handlers.
--   - publish() is synchronous — all handlers run before it returns.
--   - Negligible overhead: one table lookup + ipairs per publish.
--   - No dependencies on game-specific code — reusable across projects.

local M = {}

-- ============================================================
-- Internal State
-- ============================================================

-- subscribers[event_name] = array of {id, fn} entries.
-- Each entry has a unique numeric id for unsubscribe lookup.
local subscribers = {}

-- Monotonically increasing ID for subscription handles.
local next_id = 1

-- Optional error handler. When set, called with (event_name, handler_id, err)
-- for any handler that throws. Default: print to FCEUX output console.
M.on_error = function(event_name, handler_id, err)
    print(string.format("[event_bus] ERROR in '%s' handler #%d: %s",
        event_name, handler_id, tostring(err)))
end

-- ============================================================
-- Public API
-- ============================================================

-- subscribe(event_name, handler_fn): Register a handler for an event.
--
-- event_name: string identifying the event (e.g. "battle_started").
-- handler_fn: function(data) called when the event is published.
--             data is whatever table the publisher passes (may be nil).
--
-- Returns: a numeric handle that can be passed to unsubscribe().
function M.subscribe(event_name, handler_fn)
    if not subscribers[event_name] then
        subscribers[event_name] = {}
    end
    local id = next_id
    next_id = next_id + 1
    local list = subscribers[event_name]
    list[#list + 1] = {id = id, fn = handler_fn}
    return id
end

-- unsubscribe(handle): Remove a previously registered handler.
--
-- handle: the numeric ID returned by subscribe().
-- Returns: true if the handler was found and removed, false otherwise.
--
-- NOTE: Do NOT call unsubscribe() from inside a handler during publish().
-- Removing an entry mid-iteration shifts indices and may cause subsequent
-- handlers to be skipped. If you need conditional removal, set a flag and
-- unsubscribe after publish() returns.
function M.unsubscribe(handle)
    for event_name, list in pairs(subscribers) do
        for i, entry in ipairs(list) do
            if entry.id == handle then
                table.remove(list, i)
                -- Clean up empty lists to keep the table tidy
                if #list == 0 then
                    subscribers[event_name] = nil
                end
                return true
            end
        end
    end
    return false
end

-- publish(event_name, data): Fire an event, calling all subscribed handlers.
--
-- event_name: string identifying the event.
-- data: optional table of event-specific data passed to each handler.
--
-- Handlers are called in subscription order. Each is wrapped in pcall
-- so a failing handler doesn't prevent subsequent handlers from running.
-- Returns: nothing.
function M.publish(event_name, data)
    local list = subscribers[event_name]
    if not list then return end
    -- Iterate over a snapshot of the current list length so handlers
    -- that subscribe during publish don't run in this cycle.
    local n = #list
    for i = 1, n do
        local entry = list[i]
        if entry then
            local ok, err = pcall(entry.fn, data)
            if not ok and M.on_error then
                M.on_error(event_name, entry.id, err)
            end
        end
    end
end

-- subscriber_count(event_name): Return the number of handlers for an event.
-- Useful for debugging and testing. Returns 0 for unknown events.
function M.subscriber_count(event_name)
    local list = subscribers[event_name]
    return list and #list or 0
end

-- clear(event_name): Remove all subscribers for an event.
-- If event_name is nil, clears ALL subscribers for ALL events.
-- Primarily for testing and reset scenarios.
function M.clear(event_name)
    if event_name then
        subscribers[event_name] = nil
    else
        subscribers = {}
    end
end

return M
