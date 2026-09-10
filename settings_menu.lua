-- settings_menu.lua: grouped spoken settings with staged edits.
local config = require "config"
local combo = require "key_combo"
local tolk = require "tolk"
local M = {}
local reference = require("key_reference").new(config)
local reference_open = false
local function option(key, name, values, labels, help)
    return {key=key, name=name, values=values, labels=labels, help=help}
end
local health_thresholds, health_labels = {}, {}
for percent = 5, 100, 5 do
    health_thresholds[#health_thresholds + 1] = tostring(percent)
    health_labels[#health_labels + 1] = tostring(percent) .. " percent"
end
local groups = {
    {name="Movement", options={
        option("enable_auto_step", "Automatic tile stepping", {"false", "true"}, {"Off", "On"},
            "On completes one tile when you briefly tap a direction."),
        option("overworld_auto_walk_continuous", "Overworld auto-walk", {"false", "true"},
            {"One waypoint", "Continuous"}, "Continuous follows successive overworld waypoints until arrival or interruption.")}},
    {name="Navigation", options={
        option("darkness_navigation_limits", "Dungeon navigation", {"balanced", "authentic", "unrestricted"},
            {"Balanced", "Authentic", "Unrestricted"},
            "Balanced allows full navigation while lit. Authentic limits navigation to the current light. Unrestricted allows full navigation even without light."),
        option("object_nav_speech_coalesce_frames", "Object browsing speech delay", {"0", "12", "18"},
            {"Immediate", "Short", "Medium"}, "Waits briefly before speaking rapidly browsed objects. Short is about 0.2 seconds; medium is about 0.3 seconds."),
        option("object_sort_order", "Sort objects", {"distance", "alphabetical"},
            {"Distance", "Alphabetical"}, "Distance lists nearest objects first using tile distance, not walking-route length. Alphabetical lists objects by name. Changing order keeps your selected object. The default is Distance.")}},
    {name="Announcements", options={
        option("auto_walk_progress_interval", "Auto-walk progress", {"0", "3", "6", "12"},
            {"Off", "Every 3 steps", "Every 6 steps", "Every 12 steps"},
            "Announces progress during longer auto-walk routes."),
        option("low_health_warning", "Low-health warning", {"false", "true"}, {"Off", "On"},
            "Announces current and maximum HP once when health reaches or falls below the threshold, including when loading with low health. Healing above the threshold rearms it. Held input delays speech."),
        option("low_health_threshold_percent", "Low-health threshold", health_thresholds, health_labels,
            "Percentage of maximum HP at or below which the low-health warning fires. Choose 5 to 100 percent in steps of 5. The default is 25 percent. This has no effect while the warning is off."),
        option("travel_warnings", "Travel warnings", {"false", "true"}, {"Off", "On"},
            "Announces dangerous tiles, unsafe routes, light changes, and hazard or darkness stops. Off cancels pending travel warnings. Auto-walk crossing confirmations and recovery refusal messages remain audible. Movement safeguards still apply. Low-health warnings have their own setting. The default is On.")}},
    {name="Defaults", options={
        {name="Restore one group", action="group", help="Choose a group to restore. Changes remain pending until Control+Enter saves."},
        {name="Restore all menu settings", action="all", help="Restores only settings offered by this menu. Hotkeys and other configuration entries are preserved."}}},
}
local opened, releasing = false, false
local previous, draft, original, positions = {}, {}, {}, {}
local group_index, editing, edit_value, reset_group = 1, false, nil, 1
local help_controls = "Left and right switch groups. Up and down select options. Enter edits. Control+Enter saves and closes. Escape discards changes. Shift+F12 explains the current option."
local function say(message)
    tolk.output_interrupt(message)
    local debug_tools = package.loaded["debug_tools"]
    if debug_tools and debug_tools.info then debug_tools.info((reference_open and "KEY_REFERENCE: " or "MOD_SETTINGS: ") .. message) end
end
local function selected()
    local group = groups[group_index]
    return group.options[positions[group_index] or 1], group
end
local function label(item, value)
    for i, candidate in ipairs(item.values or {}) do
        if candidate == value then return item.labels[i] end
    end
    return "Custom: " .. tostring(value)
end
local function describe()
    local item, group = selected()
    local value = item.key and (": " .. label(item, editing and edit_value or draft[item.key])) or ""
    return group.name .. ". " .. item.name .. value .. ". " ..
        tostring(positions[group_index] or 1) .. " of " .. #group.options .. "."
end
local function normalize(key, value)
    if key == "darkness_navigation_limits" then
        if value == "true" then return "authentic" end
        if value == "false" then return "unrestricted" end
    end
    return value
end
local function restore(which)
    for i, group in ipairs(groups) do
        if which == nil or which == i then
            for _, item in ipairs(group.options) do
                if item.key then draft[item.key] = config.get_default(item.key) end
            end
        end
    end
end
function M.is_open() return opened end
function M.is_capturing() return opened or releasing end
function M.open()
    draft, original = {}, {}
    for _, group in ipairs(groups) do
        for _, item in ipairs(group.options) do
            if item.key then
                original[item.key] = config.get(item.key)
                draft[item.key] = normalize(item.key, original[item.key])
            end
        end
    end
    opened, editing = true, false
    say("Mod Settings. Control+Enter saves and closes. Escape discards changes. " .. describe())
end
local function close(message)
    opened, editing, releasing = false, false, true
    say(message)
    reference_open = false
end
function M.update(keys, joy, unavailable_reason, on_open)
    keys, joy = keys or {}, joy or {}
    local function pressed(spec) return combo.is_trigger_pressed(keys, previous, spec) end
    local captured = opened or releasing
    if releasing then
        local held = false
        for key, value in pairs(keys) do
            if value and (key == "Escape" or key == "Esc" or
                combo.is_down({[key]=true}, "up|down|left|right|enter|F11|F12")) then held = true end
        end
        for _, value in pairs(joy) do if value then held = true end end
        if not held then releasing = false end
    elseif not opened then
        if pressed(config.get("key_mod_settings")) then
            captured = true
            if unavailable_reason then
                releasing = true
                say("Settings unavailable. " .. unavailable_reason)
            else
                if on_open then on_open("mod settings opened") end
                M.open()
            end
        elseif pressed(config.get("key_mod_help")) then
            captured = true
            if unavailable_reason then
                releasing = true
                say("Key Reference unavailable. " .. unavailable_reason)
            else
                if on_open then on_open("key reference opened") end
                opened, reference_open = true, true
                say(reference.opening())
            end
        end
    elseif reference_open then
        if pressed("Escape|Esc") then close("Key Reference closed. Returning to game.")
        elseif pressed(config.get("key_mod_help")) then
            say(reference.controls() .. " " .. reference.help())
        elseif pressed("enter") then say(reference.help())
        else
            local group_delta = (pressed("right") and 1) or (pressed("left") and -1) or 0
            local item_delta = (pressed("down") and 1) or (pressed("up") and -1) or 0
            if group_delta ~= 0 or item_delta ~= 0 then
                say(reference.move(group_delta, item_delta))
            end
        end
    elseif pressed(config.get("key_mod_help")) then
        local item = selected()
        say(item.help .. " " .. help_controls)
    elseif pressed("Ctrl+enter") then
        -- An unaccepted edit is deliberately not part of the saved draft.
        if editing then say("Finish editing with Enter, or cancel the edit with Escape, before saving.")
        else
            local changes = {}
            for key, value in pairs(draft) do
                if value ~= normalize(key, original[key]) then changes[key] = value end
            end
            local ok, err = config.save_changes(changes)
            if ok then
                local sort_notice = changes.object_sort_order and ("Object sort: " ..
                    (changes.object_sort_order == "alphabetical" and "Alphabetical" or "Distance") .. ". ") or ""
                close("Settings saved. " .. sort_notice .. "Returning to game.")
            else say("Settings could not be saved: " .. tostring(err) .. ". Your changes are still pending.") end
        end
    elseif pressed("Escape|Esc") then
        if editing then editing = false; say("Edit cancelled. " .. describe())
        else close("Changes discarded. Returning to game.") end
    elseif editing then
        local item = selected()
        if pressed("enter") then
            if item.key then draft[item.key] = edit_value
            elseif item.action == "all" then restore()
            else restore(reset_group) end
            editing = false
            say("Change accepted. Control+Enter saves and closes. " .. describe())
        else
            local delta = (pressed("right|down") and 1) or (pressed("left|up") and -1) or 0
            if delta ~= 0 then
                if item.key then
                    local index = delta > 0 and 0 or #item.values + 1
                    for i, value in ipairs(item.values) do if value == edit_value then index = i end end
                    index = math.max(1, math.min(#item.values, index + delta))
                    edit_value = item.values[index]
                    say(item.name .. ": " .. label(item, edit_value))
                elseif item.action == "group" then
                    reset_group = ((reset_group - 1 + delta) % (#groups - 1)) + 1
                    say("Restore " .. groups[reset_group].name .. " defaults? Enter confirms. Escape cancels.")
                end
            end
        end
    elseif pressed("enter") then
        local item = selected()
        editing, edit_value = true, draft[item.key]
        if item.key then say("Editing " .. item.name .. ": " .. label(item, edit_value) .. ". Arrows change. Enter accepts. Escape cancels.")
        elseif item.action == "all" then say("Restore all menu settings? Enter confirms. Escape cancels.")
        else reset_group = 1; say("Restore Movement defaults? Arrows choose a group. Enter confirms. Escape cancels.") end
    else
        local delta = (pressed("right") and 1) or (pressed("left") and -1) or 0
        if delta ~= 0 then
            group_index = ((group_index - 1 + delta) % #groups) + 1
            say(describe())
        else
            delta = (pressed("down") and 1) or (pressed("up") and -1) or 0
            if delta ~= 0 then
                positions[group_index] = math.max(1, math.min(#groups[group_index].options,
                    (positions[group_index] or 1) + delta))
                say(describe())
            end
        end
    end
    previous = {}
    for key, value in pairs(keys) do previous[key] = value end
    return captured
end
return M
