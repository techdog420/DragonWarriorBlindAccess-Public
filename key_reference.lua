-- key_reference.lua: read-only command descriptions and live configured bindings.
-- Input capture and speech are shared with settings_menu.lua.
local M = {}
local function command(key, name, help)
    return {key=key, name=name, help=help}
end
local groups = {
    {name="Gameplay", commands={
        {name="Move or choose a game-menu item", binding="Arrow keys", help="Move the hero or select an item in the game's menus. With automatic tile stepping enabled, a quick tap completes one tile."},
        {name="Confirm or interact", pad="A", help="Press the NES A button to confirm, interact, or open the game's command menu."},
        {name="Cancel or go back", pad="B", help="Press the NES B button to cancel or go back in the game's menus."},
        {name="Start", pad="start", help="Press the NES Start button."},
        {name="Select", pad="select", help="Press the NES Select button."}}},
    {name="Information", commands={
        command("key_position", "Position", "Announce the current map and hero coordinates."),
        command("key_hp", "Health and magic", "Announce current and maximum HP and MP."),
        command("key_level", "Level", "Announce the hero's level."),
        command("key_gold", "Gold", "Announce current gold."),
        command("key_experience", "Experience", "Announce current experience points."),
        command("key_stats", "Full status", "Announce attributes, equipment, spells, and other hero statistics."),
        command("key_screen_text", "Screen text", "Read the text currently shown on the game screen."),
        command("key_visible_area", "Visible surroundings", "In dark dungeons, describe nearby walls, paths, branches, and objects within the current light. This physical report always respects the light boundary."),
        command("key_diag_tiles", "Tile information", "Announce the tile type at the hero's position. This can include technical information useful for reporting map problems.")}},
    {name="Object Navigation", commands={
        command("key_object_prev", "Previous object", "Select and describe the previous object in the current category and reachability view."),
        command("key_object_current", "Current object", "Repeat the selected object's description."),
        command("key_object_next", "Next object", "Select and describe the next object in the current category and reachability view."),
        command("key_services", "Quick services", "Open services on the current map, retaining sort and reachability filters. Browse with previous and next object, then use auto-walk to approach. This does not start movement or choose a town on the world map."),
        command("key_object_sort", "Switch object sorting", "Switch between Distance and Alphabetical, save immediately, and preserve the selected object and filters. This uses the same preference as Mod Settings."),
        command("key_filter", "Cycle category", "Cycle All, NPCs, Services, Treasure, Travel, and Doors."),
        command("key_filter_prev", "Previous category", "Move to the previous object category."),
        command("key_filter_all", "All categories", "Return to the All object category."),
        command("key_filter_next", "Next category", "Move to the next object category."),
        command("key_pathability_filter", "Reachability view", "Cycle All, Reachable, and Unreachable within the selected object category."),
        command("key_mark_visited", "Mark visited", "Mark the selected object as visited for this play session.")}},
    {name="Travel", commands={
        command("key_pathfind", "Preview path", "Announce a path or heading to the selected object without moving the hero."),
        command("key_auto_walk", "Auto-walk", "Calculate a fresh path and walk toward the selected object or active guided destination. A path preview is optional. Poison-swamp crossings require a separate confirmation; pressing auto-walk again within ten seconds accepts the indicated crossing."),
        command("key_stop_auto_walk", "Stop auto-walk and guidance", "Stop active or pending auto-walk, release held movement, and cancel guided Travel. The selected object is preserved."),
        command("key_route_guidance", "Start or check guidance", "Start guided travel to a supported selected Travel destination, or report the route already in progress."),
        command("key_route_status", "Route status", "Report guided route status without starting, changing, or recalculating a route."),
        command("key_freeze_npcs", "Freeze or unfreeze NPCs", "Toggle moving NPCs between frozen and unfrozen. This can help when wandering NPCs repeatedly block a route; unfreeze them when finished.")}},
    {name="Optional Movement", commands={
        command("key_teleport_exact", "Teleport to selected object", "Move directly to the selected object; NPC targets use a nearby interaction tile."),
        command("key_teleport_north", "Teleport north of object", "Move directly to the tile north of the selected object."),
        command("key_teleport_south", "Teleport south of object", "Move directly to the tile south of the selected object."),
        command("key_teleport_west", "Teleport west of object", "Move directly to the tile west of the selected object."),
        command("key_teleport_east", "Teleport east of object", "Move directly to the tile east of the selected object.")}},
    {name="Mod Settings", commands={
        command("key_mod_settings", "Open Mod Settings", "Open the grouped settings menu during normal field play. Changes are staged until Control+Enter saves; Escape discards them. Opening stops active auto-walk."),
        command("key_mod_help", "Key Reference and contextual help", "Open this read-only key reference during normal field play. Inside Mod Settings, this key explains the selected option while preserving pending edits.")}},
}
local controls = "Left and right switch groups. Up and down select commands. Enter explains without running the command. Escape closes."
local function spoken_binding(value)
    value = tostring(value or ""):match("^%s*(.-)%s*$")
    if value == "" then return "Not assigned" end
    return (value:gsub("|", " or "):gsub("[Cc][Tt][Rr][Ll]", "Control"):gsub("%+", " plus "))
end
function M.new(config, emulator)
    local index, positions = 1, {}
    local self = {}
    local function selected()
        local group = groups[index]
        return group.commands[positions[index] or 1], group
    end
    local function binding(item)
        if item.key then return spoken_binding(config.get(item.key)) end
        if item.binding then return item.binding end
        local current = emulator or package.loaded["emulator_compat"] or {}
        if current.is_bizhawk then
            return ({A="X", B="Z", start="Enter", select="Space"})[item.pad] .. " by default in BizHawk"
        end
        local key = ({A="F", B="D", start="Enter", select="S"})[item.pad]
        if config.get("enable_keyboard_input_bridge") == "false" then
            return "FCEUX keyboard bridge disabled; use your emulator controller mapping"
        end
        return key .. " through the FCEUX keyboard bridge"
    end
    function self.describe()
        local item, group = selected()
        return group.name .. ". " .. item.name .. ": " .. binding(item) .. ". " ..
            tostring(positions[index] or 1) .. " of " .. #group.commands .. "."
    end
    function self.help()
        local item = selected()
        local text = self.describe() .. " " .. item.help
        if index == 5 then
            text = text .. " Teleport skips normal movement and progression checks and can leave the session inconsistent. Save normally before experimenting; if play becomes unstable, close without saving and reload a known-good save."
        end
        return text
    end
    function self.move(group_delta, item_delta)
        if group_delta ~= 0 then
            index = ((index - 1 + group_delta) % #groups) + 1
        else
            positions[index] = math.max(1, math.min(#groups[index].commands,
                (positions[index] or 1) + item_delta))
        end
        return self.describe()
    end
    function self.opening() return "Key Reference. " .. controls .. " " .. self.describe() end
    function self.controls() return controls end
    return self
end
return M
