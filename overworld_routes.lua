-- overworld_routes.lua
-- Lightweight manual route guidance for the large Dragon Warrior world map.

local maps = require("maps")

local M = {}

local WORLD_MAP_ID = maps.WORLD_MAP_ID
local MAX_VISIBLE_ACTIVE_WAYPOINTS = 2

local SWAMP_CAVE_STAGING = {
    route_id = "kol_staging",
    continuation_route_id = "swamp_cave",
    max_start_distance = 24,
    min_x = 84,
    min_y = 8,
    max_y = 50,
    continue_after_staging = true,
}

local RIMULDAR_STAGING = {
    route_id = "swamp_cave",
    -- The longest validated segment on the south-cave-to-Rimuldar route is
    -- thirteen tiles. Farther starts must first reach and traverse Swamp Cave
    -- instead of synthesizing an unverified shortcut to the southern island.
    max_start_distance = 13,
    continue_after_staging = true,
}

local FINAL_PROGRESSION_STAGING = {
    route_id = "swamp_cave_south",
    -- The longest validated bridge-road segment is eleven tiles. Starts
    -- farther from the final-progression routes must first use the established
    -- Rimuldar-to-south-cave waypoint chain instead of synthesizing a shortcut.
    -- Off-corridor starts outside the local destination area must stage too,
    -- and should prefer whichever established approach/return route already
    -- contains their position.
    max_start_distance = 11,
    -- A player already within the local destination area should join the
    -- requested route at its nearest waypoint. Without this opt-in, the
    -- corridor guard can select the reverse route and send the player back to
    -- Swamp Cave before returning to the nearby destination.
    near_destination_snap_distance = 5,
    require_route_corridor = true,
    prefer_staging_route_corridor = true,
}

local MAGIC_TEMPLE_STAGING = {
    route_id = "rimuldar_staging",
    -- The longest validated segment on either leg is thirteen tiles. Starts
    -- farther from the temple route must first follow the established
    -- Swamp-Cave-South-to-Rimuldar corridor instead of synthesizing a shortcut.
    max_start_distance = 13,
    prefer_staging_route_corridor = true,
    continue_after_staging = true,
}

local HAUKSNESS_STAGING = {
    route_id = "kol_staging",
    continuation_route_id = "hauksness",
    -- Far starts such as Tantegel must reach the established Kol hub before
    -- joining the long western route. Starts already on the validated
    -- Kol/Garinham/Hauksness corridor remain direct.
    max_start_distance = 24,
    continue_after_staging = true,
}

local HAUKSNESS_HUB_STAGING = {
    route_id = "kol_staging",
    continuation_route_id = "hauksness_staging",
    max_start_distance = 24,
    continue_after_staging = true,
}

local CANTLIN_STAGING = {
    route_id = "hauksness_staging",
    continuation_route_id = "cantlin_hauksness",
    -- The longest validated segment on either Cantlin approach is fourteen
    -- tiles. Farther starts must first reach Hauksness through the established
    -- Kol route instead of synthesizing an unverified cross-world shortcut.
    max_start_distance = 14,
    continue_after_staging = true,
}

local CANTLIN_BYPASS_STAGING = {
    route_id = "hauksness_staging",
    continuation_route_id = "cantlin_staging",
    -- Passing routes share the validated Cantlin approach, but stop at the
    -- northwest turn instead of continuing east and descending into town.
    max_start_distance = 14,
    continue_after_staging = true,
}

local GREAT_SWAMP_STAGING = {
    route_id = "cantlin_staging",
    -- The longest live-validated segment on the local Cantlin-to-search-area
    -- route is fifteen tiles. Off-corridor or farther starts must first use
    -- the connected Cantlin itinerary instead of synthesizing a shortcut.
    max_start_distance = 15,
    near_destination_snap_distance = 5,
    require_route_corridor = true,
    prefer_staging_route_corridor = true,
    continue_after_staging = true,
}

local CANTLIN_RETURN_STAGING = {
    route_id = "cantlin_return_staging",
    continuation_route_id = "hauksness_return_staging",
    -- The Great Swamp safe pin is beyond the validated Cantlin-to-Hauksness
    -- corridor. Reach Cantlin's northwest turn on the established return route
    -- before joining that corridor, without entering town.
    max_start_distance = 14,
    continue_after_staging = true,
}

local HAUKSNESS_RETURN_STAGING = {
    route_id = "hauksness_return_staging",
    continuation_route_id = "kol_return_staging",
    -- Far southern starts must first use the established Cantlin-to-Hauksness
    -- route. Mountain Cave starts first reverse their proven local spur to the
    -- shared western-desert pin. The internal legs stop before entering towns.
    max_start_distance = 24,
    require_route_corridor = true,
    continue_after_staging = true,
}

local TANTEGEL_RETURN_STAGING = {
    route_id = "kol_return_staging",
    continuation_route_id = "tantegel_kol",
    -- Hauksness and farther southern starts must return through the proven Kol
    -- corridor before joining the established Kol-to-Tantegel route.
    max_start_distance = 24,
    continue_after_staging = true,
}

local KOL_SWAMP_CAVE_RETURN_STAGING = {
    route_id = "swamp_cave_south",
    continuation_route_id = "kol_swamp_cave_staging",
    -- Rimuldar and the southern island must first reach Swamp Cave's south
    -- entrance. The player crosses the cave manually, then this route resumes
    -- from the established north-exit corridor toward Kol.
    max_start_distance = 13,
    require_route_corridor = true,
    prefer_staging_route_corridor = true,
    continue_after_staging = true,
}

local SOUTH_ISLAND_NORTH_EXIT_STAGING = {
    route_id = "swamp_cave_south",
    -- Rimuldar and Swamp Cave's south entrance cannot reach the north-side
    -- routes directly on the World Map. First use the proven Rimuldar return,
    -- then wait for the player to cross map 0x15 manually.
    max_start_distance = 13,
    require_route_corridor = true,
    prefer_staging_route_corridor = true,
    continue_after_staging = true,
}

local SWAMP_CAVE_TANTEGEL_STAGING = {
    route_id = "kol_swamp_cave_staging",
    continuation_route_id = "tantegel_kol",
    -- North-exit starts can join the proven cave-to-Kol return directly.
    -- Southern-island starts nest through that leg's own Swamp Cave staging
    -- instead of synthesizing an unreachable shortcut across the mountains.
    max_start_distance = 13,
    require_route_corridor = true,
    continue_after_staging = true,
}

local NORTHERN_CAVE_TANTEGEL_STAGING = {
    route_id = "kol_rain_shrine_staging",
    continuation_route_id = "tantegel_kol",
    -- Northern Cave starts must reverse the established shrine corridor to
    -- Kol before joining the validated Kol-to-Tantegel route. The longest
    -- segment on that return is nine tiles, and the internal leg stops west
    -- of Kol instead of entering town.
    max_start_distance = 9,
    require_route_corridor = true,
    continue_after_staging = true,
}

local MOUNTAIN_CAVE_CONNECTOR_STAGING = {
    route_id = "kol_staging",
    continuation_route_id = "mountain_cave_connector",
    -- The connector begins on the established Kol/Hauksness corridor. Far
    -- off-corridor starts such as Tantegel must first use the Kol route.
    max_start_distance = 24,
    require_route_corridor = true,
    continue_after_staging = true,
}

local MOUNTAIN_CAVE_STAGING = {
    route_id = "mountain_cave_connector",
    continuation_route_id = "mountain_cave",
    -- The longest validated local spur segment is nine tiles. Anything
    -- farther away or off that corridor must reach its shared route pin first.
    max_start_distance = 9,
    near_destination_snap_distance = 5,
    require_route_corridor = true,
    continue_after_staging = true,
}

local EARLY_DESTINATION_KOL_STAGING = {
    route_id = "tantegel_bridge_staging",
    -- Kol is far outside the early western routes. Return on the established
    -- Kol-to-Tantegel corridor only to its shared bridge junction, then join
    -- the selected destination route without entering Tantegel.
    max_start_distance = 24,
    continue_after_staging = true,
}

local WESTERN_EARLY_DESTINATION_STAGING = {
    route_id = "tantegel_bridge_western_staging",
    -- Hauksness, Mountain Cave, Cantlin, and Great Swamp first follow their
    -- proven nested return to Kol. From there the shared bridge wrapper joins
    -- the selected early destination without entering Tantegel.
    max_start_distance = 24,
    continue_after_staging = true,
}

local NORTHWESTERN_KOL_RETURN_STAGING = {
    route_id = "northwestern_kol_return_staging",
    -- Northern Cave must reverse the Rain Shrine corridor. Mountain Cave,
    -- Hauksness, Cantlin, and Great Swamp use the nested western return. Both
    -- families stop at Kol's west doorstep so a connected destination can
    -- continue without entering town.
    max_start_distance = 13,
    require_route_corridor = true,
    prefer_staging_route_corridor = true,
    continue_after_staging = true,
}

local NORTHWESTERN_MOUNTAIN_STAGING = {
    route_id = "mountain_cave_northwestern_connector",
    max_start_distance = 9,
    require_route_corridor = true,
    continue_after_staging = true,
}

local NORTHWESTERN_CANTLIN_STAGING = {
    route_id = "hauksness_northwestern_staging",
    max_start_distance = 14,
    continue_after_staging = true,
}

local NORTHWESTERN_CANTLIN_BYPASS_STAGING = {
    route_id = "hauksness_northwestern_staging",
    continuation_route_id = "cantlin_northwestern_staging",
    max_start_distance = 14,
    continue_after_staging = true,
}

local NORTHWESTERN_GREAT_SWAMP_STAGING = {
    route_id = "cantlin_northwestern_staging",
    max_start_distance = 15,
    require_route_corridor = true,
    prefer_staging_route_corridor = true,
    continue_after_staging = true,
}

local NORTHERN_CAVE_BRIDGE_STAGING = {
    route_id = "kol_rain_shrine_staging",
    continuation_route_id = "tantegel_bridge_staging",
    -- Northern Cave is 24 steps from the nearest bridge-return waypoint, but
    -- the proven route first returns through the shrine corridor. Kol and its
    -- west doorstep remain within thirteen steps of the bridge leg.
    max_start_distance = 13,
    continue_after_staging = true,
}

local SWAMP_CAVE_NORTH_BRIDGE_STAGING = {
    route_id = "kol_swamp_cave_staging",
    continuation_route_id = "tantegel_bridge_swamp_cave_staging",
    -- Swamp Cave north already has a proven return to Kol. Reuse that route
    -- before joining the eastern bridge corridor instead of synthesizing a
    -- sixty-step cross-world segment.
    max_start_distance = 13,
    require_route_corridor = true,
    continue_after_staging = true,
}

local SWAMP_CAVE_NORTH_EARLY_DESTINATION_STAGING = {
    route_id = "tantegel_bridge_swamp_cave_staging",
    max_start_distance = 24,
    continue_after_staging = true,
}

local SWAMP_CAVE_SOUTH_EARLY_DESTINATION_STAGING = {
    route_id = "tantegel_bridge_swamp_cave_staging",
    -- The nested bridge staging already returns through Swamp Cave and Kol.
    -- Keep the southern-origin selector separate so northern variants retain
    -- their current behavior. Magic Temple and final-island starts nest through
    -- their established returns before joining this shared cave chain.
    max_start_distance = 24,
    require_route_corridor = true,
    prefer_staging_route_corridor = true,
    continue_after_staging = true,
}

local SWAMP_CAVE_NORTH_KOL_DESTINATION_STAGING = {
    route_id = "kol_swamp_cave_staging",
    -- North-cave and western destinations share the proven return to Kol.
    -- Starts on their established corridors remain direct.
    max_start_distance = 13,
    require_route_corridor = true,
    continue_after_staging = true,
}

local SWAMP_CAVE_NORTH_WESTERN_CONNECTOR_STAGING = {
    route_id = "kol_swamp_cave_staging",
    continuation_route_id = "mountain_cave_swamp_cave_north_connector",
    max_start_distance = 13,
    require_route_corridor = true,
    continue_after_staging = true,
}

local SWAMP_CAVE_NORTH_MOUNTAIN_STAGING = {
    route_id = "mountain_cave_swamp_cave_north_connector",
    -- The final local spur retains the canonical nine-tile staging bound.
    max_start_distance = 9,
    require_route_corridor = true,
    continue_after_staging = true,
}

local SWAMP_CAVE_NORTH_HAUKSNESS_HUB_STAGING = {
    route_id = "kol_swamp_cave_staging",
    continuation_route_id = "hauksness_swamp_cave_north_staging",
    -- Reach Kol on the proven cave return before joining the established
    -- western route. The continuation stops outside the Hauksness ruins.
    max_start_distance = 13,
    require_route_corridor = true,
    continue_after_staging = true,
}

local SWAMP_CAVE_NORTH_CANTLIN_STAGING = {
    route_id = "hauksness_swamp_cave_north_staging",
    -- The longest validated segment on the Hauksness-to-Cantlin route is
    -- fourteen tiles. Starts farther away must use the connected cave route.
    max_start_distance = 14,
    continue_after_staging = true,
}

local SWAMP_CAVE_NORTH_CANTLIN_BYPASS_STAGING = {
    route_id = "hauksness_swamp_cave_north_staging",
    continuation_route_id = "cantlin_swamp_cave_north_staging",
    -- Great Swamp travel uses the same Hauksness route, then stops at
    -- Cantlin's northwest turn instead of entering town.
    max_start_distance = 14,
    continue_after_staging = true,
}

local SWAMP_CAVE_NORTH_GREAT_SWAMP_STAGING = {
    route_id = "cantlin_swamp_cave_north_staging",
    max_start_distance = 15,
    require_route_corridor = true,
    prefer_staging_route_corridor = true,
    continue_after_staging = true,
}

local SWAMP_CAVE_NORTH_TO_SOUTH_STAGING = {
    route_id = "swamp_cave_north_entry_staging",
    -- The two cave entrances are separated by impassable overworld terrain.
    -- A north-exit start must re-enter the cave instead of synthesizing the
    -- apparent five-tile south shortcut to the other entrance.
    max_start_distance = 1,
    continue_after_staging = true,
}

local GARINHAM_KOL_STAGING = {
    route_id = "tantegel_garinham_staging",
    -- Garinham first returns on the established eastern road only to the
    -- shared bridge junction. From there the existing Kol bypass can continue
    -- without entering Brecconary or Tantegel.
    max_start_distance = 24,
    require_route_corridor = true,
    continue_after_staging = true,
}

local GARINHAM_SWAMP_CAVE_STAGING = {
    route_id = "kol_garinham_staging",
    -- Once the eastern return reaches the shared bridge junction, follow the
    -- existing Kol and north-cave corridors instead of synthesizing a direct
    -- cross-world segment from Garinham.
    max_start_distance = 13,
    require_route_corridor = true,
    continue_after_staging = true,
}

local MAINLAND_SWAMP_CAVE_SOUTH_STAGING = {
    route_id = "swamp_cave",
    continuation_route_id = "swamp_cave_south_swamp_cave_north",
    -- The two cave entrances are close in coordinates but separated by
    -- impassable overworld terrain. Mainland starts must reach the north
    -- entrance and cross map 0x15 manually before continuing south.
    max_start_distance = 1,
    require_route_corridor = true,
    prefer_staging_route_corridor = true,
    continue_after_staging = true,
}

local SWAMP_CAVE_NORTH_MAGIC_TEMPLE_STAGING = {
    route_id = "rimuldar_swamp_cave_north_staging",
    -- After the manual cave crossing, follow the proven Rimuldar approach only
    -- to its east doorstep. The selected temple route then continues south
    -- without entering town or synthesizing a shortcut across the mountains.
    max_start_distance = 13,
    require_route_corridor = true,
    prefer_staging_route_corridor = true,
    continue_after_staging = true,
}

local ROUTES = {
    brecconary = {
        id = "brecconary",
        title = "Brecconary",
        aliases = {"brecconary", "breconary", "town", "first town"},
        target_object_ids = {"overworld_brecconary"},
        destination_maps = {0x08},
        waypoints = {
            {x = 2, y = 2, name = "Garinham road", radius = 1},
            {x = 5, y = 4, name = "Garinham outskirts", radius = 1},
            {x = 8, y = 3, name = "Garinham north coast west lane", radius = 1},
            {x = 14, y = 3, name = "Garinham north coast lane", radius = 0},
            {x = 14, y = 4, name = "Garinham mountain shoulder", radius = 0},
            {x = 15, y = 4, name = "Garinham shoulder east step", radius = 0},
            {x = 16, y = 5, name = "Garinham shoulder bend", radius = 0},
            {x = 16, y = 6, name = "Garinham east ridge", radius = 0},
            {x = 19, y = 6, name = "Garinham ridge entry", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 20, y = 7, name = "Garinham field east lane", radius = 0},
            {x = 20, y = 9, name = "Garinham east field", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 21, y = 10, name = "Garinham field road bend", radius = 0},
            {x = 21, y = 11, name = "Cave road north edge", radius = 0},
            {x = 23, y = 11, name = "Cave road west lane", radius = 0},
            {x = 23, y = 13, name = "Cave road south lane", radius = 1},
            {x = 28, y = 13, name = "Erdrick's Cave road", radius = 1},
            {x = 28, y = 20, name = "North trail marker", radius = 1},
            {x = 32, y = 19, name = "North ridge bend", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 35, y = 24, name = "Eastern mountain lane", radius = 0},
            {x = 35, y = 32, name = "East choke approach", radius = 0},
            {x = 38, y = 32, name = "Upper bridge lane", radius = 0},
            {
                x = 38,
                y = 34,
                name = "Bridge west bend",
                radius = 0,
                axis_order = {"horizontal", "vertical"},
            },
            {
                x = 38,
                y = 36,
                name = "Bridge lower west lane",
                radius = 0,
            },
            {
                x = 44,
                y = 38,
                name = "Bridge south bend",
                radius = 1,
                warning = "Bridge crossing. Monsters should become safer beyond this point.",
            },
            {x = 48, y = 41, name = "Brecconary", radius = 0, final = true},
        },
    },
    garinham = {
        id = "garinham",
        title = "Garinham",
        aliases = {"garinham", "garinham town", "garin", "galen", "galenholm"},
        target_object_ids = {"overworld_garinham"},
        destination_maps = {0x09},
        waypoints = {
            {x = 43, y = 43, name = "Tantegel Castle road", radius = 1},
            {x = 47, y = 41, name = "Brecconary west bypass", radius = 0},
            {
                x = 44,
                y = 38,
                name = "Bridge south bend",
                radius = 1,
                warning = "Bridge crossing. Monsters may become more dangerous beyond this point.",
            },
            {x = 38, y = 36, name = "Bridge lower west lane", radius = 0},
            {
                x = 38,
                y = 34,
                name = "Bridge west bend",
                radius = 0,
                axis_order = {"horizontal", "vertical"},
            },
            {x = 38, y = 32, name = "Upper bridge lane", radius = 0},
            {x = 35, y = 32, name = "East choke approach", radius = 0},
            {x = 35, y = 24, name = "Eastern mountain lane", radius = 0},
            {x = 32, y = 19, name = "North ridge bend", radius = 1},
            {x = 28, y = 20, name = "North trail marker", radius = 1},
            {x = 28, y = 13, name = "Erdrick's Cave road", radius = 1},
            {x = 23, y = 13, name = "Cave road south lane", radius = 1},
            {x = 23, y = 11, name = "Cave road west lane", radius = 0},
            {x = 21, y = 11, name = "Cave road north edge", radius = 0},
            {x = 21, y = 10, name = "Garinham field road bend", radius = 0},
            {x = 20, y = 9, name = "Garinham east field", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 20, y = 7, name = "Garinham field east lane", radius = 0},
            {x = 19, y = 6, name = "Garinham ridge entry", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 16, y = 6, name = "Garinham east ridge", radius = 0},
            {x = 16, y = 5, name = "Garinham shoulder bend", radius = 0},
            {x = 15, y = 4, name = "Garinham shoulder east step", radius = 0},
            {x = 14, y = 4, name = "Garinham mountain shoulder", radius = 0},
            {x = 14, y = 3, name = "Garinham north coast lane", radius = 0},
            {x = 8, y = 3, name = "Garinham north coast west lane", radius = 1},
            {x = 5, y = 4, name = "Garinham outskirts", radius = 1},
            {x = 2, y = 2, name = "Garinham approach", radius = 0},
            {x = 1, y = 2, name = "Garinham", radius = 0, final = true},
        },
    },
    kol = {
        id = "kol",
        title = "Kol",
        aliases = {"kol", "kol town", "kol village", "fairy flute", "faerie flute", "faeries flute"},
        target_object_ids = {"overworld_kol"},
        destination_maps = {0x07},
        waypoints = {
            {x = 43, y = 43, name = "Tantegel Castle road", radius = 1},
            {x = 47, y = 41, name = "Brecconary west bypass", radius = 0},
            {
                x = 44,
                y = 38,
                name = "Bridge south bend",
                radius = 1,
                warning = "Bridge crossing. Monsters may become more dangerous beyond this point.",
            },
            {x = 38, y = 36, name = "Bridge lower west lane", radius = 0},
            {x = 38, y = 34, name = "Bridge west bend", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 38, y = 32, name = "Upper bridge lane", radius = 0},
            {x = 35, y = 32, name = "East choke approach", radius = 0},
            {x = 35, y = 24, name = "Eastern mountain lane", radius = 0},
            {x = 32, y = 19, name = "North ridge bend", radius = 1},
            {x = 28, y = 20, name = "North trail marker", radius = 1},
            {x = 28, y = 13, name = "Erdrick's Cave road", radius = 1},
            {x = 35, y = 13, name = "North Alefgard west road", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 45, y = 13, name = "North Alefgard east road", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 54, y = 15, name = "Northeast bridge west approach", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 58, y = 18, name = "Northeast bridge west bend", radius = 0, axis_order = {"vertical", "horizontal"}},
            {x = 59, y = 19, name = "Northeast bridge lower west lane", radius = 0},
            {x = 61, y = 19, name = "Northeast bridge south lane", radius = 0},
            {
                x = 61,
                y = 18,
                name = "Northeast bridge",
                radius = 1,
                axis_order = {"horizontal", "vertical"},
                warning = "Northeast bridge crossing. Monsters may become more dangerous beyond this point.",
            },
            {x = 74, y = 18, name = "North Alefgard bridge road", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 84, y = 26, name = "Kol southwest track", radius = 1, axis_order = {"vertical", "horizontal"}},
            {
                x = 90,
                y = 37,
                name = "Kol southwest bridge",
                radius = 0,
                warning = "Kol southwest bridge crossing. Stronger Kol-area monsters may appear beyond this point.",
            },
            {x = 92, y = 37, name = "Kol bridge east lane", radius = 0},
            {x = 92, y = 36, name = "Kol lower south lane", radius = 0},
            {x = 93, y = 36, name = "Kol south road bend", radius = 0},
            {x = 93, y = 35, name = "Kol south road lower bend", radius = 0},
            {x = 96, y = 35, name = "Kol south road east lane", radius = 0},
            {x = 96, y = 32, name = "Kol south road", radius = 1},
            {x = 98, y = 32, name = "Kol south road lower east lane", radius = 0},
            {x = 98, y = 26, name = "Kol south road east detour", radius = 0, axis_order = {"vertical", "horizontal"}},
            {x = 96, y = 21, name = "West of Kol north lane", radius = 1},
            {x = 96, y = 13, name = "Kol forest west edge", radius = 1},
            {x = 104, y = 10, name = "Kol", radius = 0, final = true},
        },
    },
    northern_cave = {
        id = "northern_cave",
        title = "Northern Cave",
        aliases = {
            "northern cave",
            "north cave",
            "cave of rain",
            "rain cave",
            "rain shrine",
            "shrine of rain",
            "staff of rain",
            "harp shrine",
            "silver harp",
            "cave west of kol",
            "shrine west of kol",
        },
        target_object_ids = {"overworld_northern_cave"},
        destination_maps = {0x0D},
        staging = {
            route_id = "kol_staging",
            max_start_distance = 24,
            min_x = 75,
            max_y = 21,
            continue_after_staging = true,
        },
        waypoints = {
            {x = 104, y = 10, name = "Kol", radius = 1},
            {x = 96, y = 13, name = "Kol forest west edge", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 92, y = 10, name = "West of Kol forest bend", radius = 1, axis_order = {"vertical", "horizontal"}},
            {x = 92, y = 17, name = "Rain shrine east-shore detour", radius = 1},
            {x = 90, y = 17, name = "Rain shrine east-shore west step", radius = 0},
            {x = 90, y = 18, name = "Rain shrine east-shore lower turn", radius = 0},
            {x = 89, y = 18, name = "Rain shrine lower shore west step", radius = 0},
            {x = 89, y = 19, name = "Rain shrine lower shore turn", radius = 0},
            {x = 83, y = 19, name = "Rain shrine south shore road", radius = 1},
            {x = 83, y = 18, name = "Rain shrine southwest rise", radius = 0},
            {x = 82, y = 18, name = "Rain shrine southwest jog", radius = 0},
            {x = 82, y = 17, name = "Rain shrine west-side lower road", radius = 0},
            {x = 80, y = 17, name = "Rain shrine west-side west step", radius = 0},
            {x = 80, y = 16, name = "Rain shrine west-side rise", radius = 0},
            {x = 79, y = 16, name = "Rain shrine west-side jog", radius = 0},
            {x = 79, y = 15, name = "Rain shrine west-side road", radius = 0},
            {x = 76, y = 15, name = "Rain shrine west coast south bend", radius = 0},
            {x = 76, y = 14, name = "Rain shrine west coast lower lane", radius = 0},
            {x = 75, y = 14, name = "Rain shrine west coast turn", radius = 0},
            {x = 75, y = 5, name = "Rain shrine west coast north road", radius = 1},
            {x = 76, y = 5, name = "Rain shrine northwest coast step", radius = 0},
            {x = 76, y = 4, name = "Rain shrine northwest coast lane", radius = 0},
            {x = 77, y = 4, name = "Rain shrine island lower step", radius = 0},
            {x = 77, y = 3, name = "Rain shrine island west lane", radius = 0},
            {x = 78, y = 3, name = "Rain shrine island approach", radius = 1},
            {x = 80, y = 1, name = "Rain shrine entrance approach", radius = 1, axis_order = {"vertical", "horizontal"}},
            {x = 81, y = 1, name = "Northern Cave", radius = 0, final = true},
        },
    },
    kol_rain_shrine = {
        id = "kol_rain_shrine",
        title = "Kol",
        aliases = {"kol from rain shrine", "rain shrine to kol", "northern cave to kol"},
        target_object_ids = {"overworld_kol"},
        destination_maps = {0x07},
        waypoints = {
            {x = 81, y = 1, name = "Northern Cave", radius = 1},
            {x = 80, y = 1, name = "Rain shrine entrance approach", radius = 0, axis_order = {"horizontal", "vertical"}},
            {
                x = 78,
                y = 3,
                name = "Rain shrine island approach",
                radius = 1,
                -- Live return evidence: (80,2)->DOWN is engine-blocked.
                -- Reach column 78 before descending onto the island road.
                axis_order = {"horizontal", "vertical"},
            },
            {x = 77, y = 3, name = "Rain shrine island west lane", radius = 0},
            {x = 77, y = 4, name = "Rain shrine island lower step", radius = 0},
            {x = 76, y = 4, name = "Rain shrine northwest coast lane", radius = 0},
            {x = 76, y = 5, name = "Rain shrine northwest coast step", radius = 0},
            {x = 75, y = 5, name = "Rain shrine west coast north road", radius = 1},
            {
                x = 75,
                y = 14,
                name = "Rain shrine west coast turn",
                radius = 0,
                -- Radius advancement can skip the adjacent (75,5) pin while
                -- standing at (76,5). Move west before the long descent.
                axis_order = {"horizontal", "vertical"},
            },
            {x = 76, y = 14, name = "Rain shrine west coast lower lane", radius = 0},
            {x = 76, y = 15, name = "Rain shrine west coast south bend", radius = 0},
            {x = 79, y = 15, name = "Rain shrine west-side road", radius = 0},
            {x = 79, y = 16, name = "Rain shrine west-side jog", radius = 0},
            {x = 80, y = 16, name = "Rain shrine west-side rise", radius = 0},
            {x = 80, y = 17, name = "Rain shrine west-side west step", radius = 0},
            {x = 82, y = 17, name = "Rain shrine west-side lower road", radius = 0},
            {x = 82, y = 18, name = "Rain shrine southwest jog", radius = 0},
            {x = 83, y = 18, name = "Rain shrine southwest rise", radius = 0},
            {x = 83, y = 19, name = "Rain shrine south shore road", radius = 1},
            {x = 89, y = 19, name = "Rain shrine lower shore turn", radius = 0},
            {x = 89, y = 18, name = "Rain shrine lower shore west step", radius = 0},
            {x = 90, y = 18, name = "Rain shrine east-shore lower turn", radius = 0},
            {x = 90, y = 17, name = "Rain shrine east-shore west step", radius = 0},
            {x = 92, y = 17, name = "Rain shrine east-shore detour", radius = 1},
            {x = 92, y = 10, name = "West of Kol forest bend", radius = 1, axis_order = {"vertical", "horizontal"}},
            {x = 96, y = 13, name = "Kol forest west edge", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 104, y = 10, name = "Kol", radius = 0, final = true},
        },
    },
    kol_swamp_cave = {
        id = "kol_swamp_cave",
        title = "Kol",
        aliases = {"kol from swamp cave", "swamp cave to kol", "swamp to kol", "rimuldar cave to kol"},
        target_object_ids = {"overworld_kol"},
        destination_maps = {0x07},
        waypoints = {
            {x = 104, y = 44, name = "Swamp Cave", radius = 1},
            {
                x = 104,
                y = 43,
                name = "Swamp Cave doorstep",
                radius = 0,
                warning = "Poison swamp return to Kol. Watch HP while crossing.",
            },
            {x = 102, y = 43, name = "Swamp Cave entrance row", radius = 0},
            {x = 102, y = 42, name = "Swamp Cave entrance west lane", radius = 0},
            {x = 97, y = 42, name = "Swamp Cave lower swamp turn", radius = 0},
            {x = 97, y = 41, name = "Swamp Cave lower swamp lane", radius = 0},
            {x = 94, y = 41, name = "Swamp Cave lower swamp drop", radius = 0},
            {x = 94, y = 40, name = "Swamp Cave lower west approach", radius = 0},
            {x = 92, y = 37, name = "Kol bridge east lane", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 92, y = 36, name = "Kol lower south lane", radius = 0},
            {x = 93, y = 36, name = "Kol south road bend", radius = 0},
            {x = 93, y = 35, name = "Kol south road lower bend", radius = 0},
            {x = 96, y = 35, name = "Kol south road east lane", radius = 0},
            {x = 96, y = 32, name = "Kol south road", radius = 1},
            {x = 98, y = 32, name = "Kol south road lower east lane", radius = 0},
            {x = 98, y = 26, name = "Kol south road east detour", radius = 0, axis_order = {"vertical", "horizontal"}},
            {x = 96, y = 21, name = "West of Kol north lane", radius = 1},
            {x = 96, y = 13, name = "Kol forest west edge", radius = 1},
            {x = 104, y = 10, name = "Kol", radius = 0, final = true},
        },
    },
    swamp_cave = {
        id = "swamp_cave",
        title = "Swamp Cave",
        aliases = {
            "swamp cave",
            "swamp",
            "rimuldar cave",
            "cave to rimuldar",
            "quagmire cave",
        },
        target_object_ids = {"overworld_swamp_cave"},
        destination_maps = {0x15},
        staging = SWAMP_CAVE_STAGING,
        waypoints = {
            {x = 104, y = 10, name = "Kol", radius = 1},
            {x = 96, y = 13, name = "Kol forest west edge", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 96, y = 21, name = "West of Kol north lane", radius = 1},
            {x = 98, y = 26, name = "Kol south road east detour", radius = 0, axis_order = {"vertical", "horizontal"}},
            {x = 98, y = 32, name = "Kol south road lower east lane", radius = 0},
            {x = 96, y = 32, name = "Kol south road", radius = 1},
            {x = 96, y = 35, name = "Kol south road east lane", radius = 0},
            {x = 93, y = 35, name = "Kol south road lower bend", radius = 0},
            {x = 93, y = 36, name = "Kol south road bend", radius = 0},
            {x = 92, y = 36, name = "Kol lower south lane", radius = 0},
            {x = 92, y = 37, name = "Kol bridge east lane", radius = 0},
            {
                x = 94,
                y = 40,
                name = "Swamp Cave lower west approach",
                radius = 0,
                warning = "Poison swamp ahead before the cave. Watch HP before continuing.",
            },
            {x = 94, y = 41, name = "Swamp Cave lower swamp drop", radius = 0},
            {x = 97, y = 41, name = "Swamp Cave lower swamp lane", radius = 0},
            {x = 97, y = 42, name = "Swamp Cave lower swamp turn", radius = 0},
            {x = 102, y = 42, name = "Swamp Cave entrance west lane", radius = 0},
            {x = 102, y = 43, name = "Swamp Cave entrance row", radius = 0},
            {x = 104, y = 43, name = "Swamp Cave doorstep", radius = 0},
            {x = 104, y = 44, name = "Swamp Cave", radius = 0, final = true},
        },
    },
    swamp_cave_bridge = {
        id = "swamp_cave_bridge",
        title = "Swamp Cave",
        aliases = {"swamp cave from bridge", "kol bridge to swamp cave"},
        target_object_ids = {"overworld_swamp_cave"},
        destination_maps = {0x15},
        staging = SWAMP_CAVE_STAGING,
        waypoints = {
            {x = 90, y = 37, name = "Kol southwest bridge", radius = 0},
            {x = 92, y = 37, name = "Kol bridge east lane", radius = 0},
            {
                x = 94,
                y = 40,
                name = "Swamp Cave lower west approach",
                radius = 0,
                warning = "Poison swamp ahead before the cave. Watch HP before continuing.",
            },
            {x = 94, y = 41, name = "Swamp Cave lower swamp drop", radius = 0},
            {x = 97, y = 41, name = "Swamp Cave lower swamp lane", radius = 0},
            {x = 97, y = 42, name = "Swamp Cave lower swamp turn", radius = 0},
            {x = 102, y = 42, name = "Swamp Cave entrance west lane", radius = 0},
            {x = 102, y = 43, name = "Swamp Cave entrance row", radius = 0},
            {x = 104, y = 43, name = "Swamp Cave doorstep", radius = 0},
            {x = 104, y = 44, name = "Swamp Cave", radius = 0, final = true},
        },
    },
    rimuldar = {
        id = "rimuldar",
        title = "Rimuldar",
        aliases = {
            "rimuldar",
            "magic keys",
            "magic key",
            "key shop",
            "rimuldar town",
        },
        target_object_ids = {"overworld_rimuldar"},
        destination_maps = {0x0B},
        staging = RIMULDAR_STAGING,
        selection_anchors = {
            {x = 81, y = 1, max_distance = 4},
            {x = 25, y = 89, max_distance = 4},
            {x = 29, y = 57, max_distance = 4},
            {x = 73, y = 102, max_distance = 4},
            {x = 89, y = 112, max_distance = 4},
        },
        waypoints = {
            {
                x = 104,
                y = 49,
                name = "Swamp Cave South Entrance",
                radius = 1,
                warning = "Poison swamp ahead after leaving the cave. Watch HP while crossing.",
            },
            {x = 93, y = 49, name = "North Rimuldar west safer route", radius = 0, axis_order = {"horizontal", "vertical"}},
            -- Live route execution and same-origin raw movement both proved
            -- (93,52)->DOWN blocked. Reuse the validated reverse corridor so
            -- the outbound route turns west at row 52 and crosses the open
            -- north/south seam on column 86 instead.
            {x = 92, y = 52, name = "South cave west ridge road", radius = 0},
            {x = 86, y = 52, name = "South island west ridge north bend", radius = 0},
            {x = 86, y = 54, name = "South island west ridge east wall", radius = 0},
            {x = 83, y = 54, name = "South island west ridge lane", radius = 0},
            {x = 83, y = 56, name = "South island west ridge foot", radius = 0},
            {x = 85, y = 56, name = "South island west pocket bend", radius = 0},
            {x = 85, y = 58, name = "South island west pocket lower lane", radius = 0},
            {x = 88, y = 58, name = "Safer west route west edge", radius = 0},
            {
                x = 88,
                y = 71,
                name = "Rimuldar lake west road",
                radius = 1,
                warning = "Rimuldar-area monsters are dangerous. Sleep is useful on the way in.",
            },
            {x = 90, y = 71, name = "Rimuldar west lake bend", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 90, y = 72, name = "Rimuldar west lake road", radius = 0},
            {x = 97, y = 72, name = "Rimuldar north wall west end", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 97, y = 71, name = "Rimuldar north wall bypass", radius = 0},
            {x = 98, y = 70, name = "Rimuldar north wall corner", radius = 0, axis_order = {"vertical", "horizontal"}},
            {x = 98, y = 69, name = "Rimuldar north approach west lane", radius = 0},
            {x = 99, y = 69, name = "Rimuldar north approach bend", radius = 0},
            {x = 99, y = 68, name = "Rimuldar north ridge lane", radius = 0},
            {x = 100, y = 67, name = "Rimuldar north ridge step", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 101, y = 67, name = "Rimuldar north ridge east lane", radius = 0},
            {x = 102, y = 68, name = "Rimuldar northeast shoulder", radius = 0},
            {x = 103, y = 68, name = "Rimuldar northeast bend", radius = 0},
            {x = 105, y = 68, name = "Rimuldar northeast lane", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 106, y = 69, name = "Rimuldar east upper road", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 106, y = 70, name = "Rimuldar east road bend", radius = 0},
            {x = 107, y = 70, name = "Rimuldar east road", radius = 0},
            {x = 108, y = 70, name = "Rimuldar east approach upper lane", radius = 0},
            {x = 108, y = 71, name = "Rimuldar east approach", radius = 0},
            {x = 107, y = 71, name = "Rimuldar east bend", radius = 0},
            {x = 107, y = 72, name = "Rimuldar east gate lane", radius = 0},
            {x = 103, y = 72, name = "Rimuldar east doorstep", radius = 0},
            {x = 102, y = 72, name = "Rimuldar", radius = 0, final = true},
        },
    },
    magic_temple = {
        id = "magic_temple",
        title = "Magic Temple",
        aliases = {
            "magic temple",
            "southern cave",
            "southern temple",
            "southern shrine",
            "holy shrine",
            "rainbow drop",
            "rainbow drop sage",
        },
        target_object_ids = {"overworld_southern_cave"},
        destination_maps = {0x0E},
        staging = MAGIC_TEMPLE_STAGING,
        waypoints = {
            {
                x = 102,
                y = 72,
                name = "Rimuldar",
                radius = 1,
                warning = "Guide and map-derived Magic Temple route. Strong monsters remain south of Rimuldar; keep HP high.",
            },
            {x = 103, y = 72, name = "Rimuldar east doorstep", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 107, y = 72, name = "Rimuldar east gate lane", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 107, y = 76, name = "Rimuldar south ridge upper turn", radius = 0},
            {x = 110, y = 76, name = "Rimuldar south ridge east lane", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 110, y = 86, name = "Southern road east wall", radius = 0},
            {x = 106, y = 86, name = "Southern road hill turn", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 106, y = 99, name = "Southern bridge east approach", radius = 0},
            {
                x = 102,
                y = 99,
                name = "Southern bridge west landing",
                radius = 0,
                axis_order = {"horizontal", "vertical"},
                warning = "Crossing the bridge to the Magic Temple island.",
            },
            {x = 102, y = 107, name = "Temple island northwest descent", radius = 0},
            {x = 101, y = 107, name = "Temple mountain west entry", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 101, y = 110, name = "Temple west ridge lower lane", radius = 0},
            {x = 102, y = 110, name = "Temple lower ridge first east step", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 102, y = 111, name = "Temple lower ridge first south step", radius = 0},
            {x = 103, y = 111, name = "Temple lower ridge second east step", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 103, y = 113, name = "Temple lower ridge second south step", radius = 0},
            {x = 104, y = 113, name = "Temple southwest corner", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 104, y = 114, name = "Temple south approach west", radius = 0},
            {x = 107, y = 114, name = "Temple south approach east", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 107, y = 111, name = "Temple southeast inner turn", radius = 0},
            {x = 108, y = 111, name = "Temple inner east lane", radius = 0, axis_order = {"horizontal", "vertical"}},
            {
                x = 108,
                y = 109,
                name = "Magic Temple",
                radius = 0,
                final = true,
                warning = "Use the STAIRS command on this tile to enter the Magic Temple, then speak to the sage with Erdrick's Token, the Stones of Sunlight, and the Staff of Rain.",
            },
        },
    },
    rimuldar_magic_temple = {
        id = "rimuldar_magic_temple",
        title = "Rimuldar",
        aliases = {
            "rimuldar from magic temple",
            "magic temple to rimuldar",
            "rimuldar from southern cave",
            "southern cave to rimuldar",
            "return to rimuldar from temple",
        },
        target_object_ids = {"overworld_rimuldar"},
        destination_maps = {0x0B},
        waypoints = {
            {
                x = 108,
                y = 109,
                name = "Magic Temple",
                radius = 1,
                warning = "Map-derived return route to Rimuldar. Leave the temple mountain ring through the southern opening.",
            },
            {x = 108, y = 111, name = "Temple inner east lane", radius = 0},
            {x = 107, y = 111, name = "Temple southeast inner turn", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 107, y = 114, name = "Temple south approach east", radius = 0},
            {x = 104, y = 114, name = "Temple south approach west", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 104, y = 113, name = "Temple southwest corner", radius = 0},
            {x = 103, y = 113, name = "Temple lower ridge second south step", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 103, y = 111, name = "Temple lower ridge second east step", radius = 0},
            {x = 102, y = 111, name = "Temple lower ridge first south step", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 102, y = 110, name = "Temple lower ridge first east step", radius = 0},
            {x = 101, y = 110, name = "Temple west ridge lower lane", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 101, y = 107, name = "Temple mountain west entry", radius = 0},
            {x = 102, y = 107, name = "Temple island northwest descent", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 102, y = 99, name = "Southern bridge west landing", radius = 0},
            {
                x = 106,
                y = 99,
                name = "Southern bridge east approach",
                radius = 0,
                axis_order = {"horizontal", "vertical"},
                warning = "Crossing the southern bridge back toward Rimuldar.",
            },
            {x = 106, y = 86, name = "Southern road hill turn", radius = 0},
            {x = 110, y = 86, name = "Southern road east wall", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 110, y = 76, name = "Rimuldar south ridge east lane", radius = 0},
            {x = 107, y = 76, name = "Rimuldar south ridge upper turn", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 107, y = 72, name = "Rimuldar east gate lane", radius = 0},
            {x = 103, y = 72, name = "Rimuldar east doorstep", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 102, y = 72, name = "Rimuldar", radius = 0, final = true, axis_order = {"horizontal", "vertical"}},
        },
    },
    swamp_cave_south = {
        id = "swamp_cave_south",
        title = "Swamp Cave South Entrance",
        -- Cave entry triggers when the hero steps onto this tile. Connected
        -- itineraries must remain on this leg until the cave map is actually
        -- observed, or autowalk will target the north exit directly from the
        -- southern island. A route started while already on the tile requires
        -- stepping off and back on to retrigger entry.
        staged_handoff_requires_destination_map = true,
        staged_transition_message =
            "Swamp Cave opens automatically when you step onto this tile. " ..
            "If already here, step off and back on, then cross to the north exit.",
        aliases = {
            "swamp cave south",
            "south swamp cave",
            "swamp cave south entrance",
            "rimuldar cave return",
            "rimuldar to cave",
            "south island cave",
        },
        target_object_ids = {"overworld_swamp_cave_south_entrance"},
        -- Preserve either final-progression Travel selection while this route
        -- stages it through the proven Rimuldar-to-cave detour.
        compatible_target_object_ids = {
            "overworld_rainbow_bridge",
            "overworld_charlock_castle",
        },
        destination_maps = {0x15},
        waypoints = {
            {x = 102, y = 72, name = "Rimuldar", radius = 1},
            {x = 103, y = 72, name = "Rimuldar east doorstep", radius = 0},
            {x = 107, y = 72, name = "Rimuldar east gate lane", radius = 0, axis_order = {"horizontal", "vertical"}},
            {
                x = 107,
                y = 71,
                name = "Rimuldar east bend",
                radius = 0,
                route_hold_after_movement_start_frames = 60,
                route_early_twitch_timeout_frames = 60,
            },
            -- Live same-origin movement carries directly north from (107,71)
            -- to (107,70); the older east detour was unnecessary and caused
            -- the route executor to reject the clean carry as off-path drift.
            {x = 107, y = 70, name = "Rimuldar east road", radius = 0},
            {x = 106, y = 70, name = "Rimuldar east road bend", radius = 0},
            {x = 106, y = 69, name = "Rimuldar east upper road", radius = 0},
            {
                x = 105,
                y = 68,
                name = "Rimuldar northeast lane",
                radius = 0,
                route_reset_movement_on_turn_settle = true,
            },
            {x = 103, y = 68, name = "Rimuldar northeast bend", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 102, y = 68, name = "Rimuldar northeast shoulder", radius = 0},
            {
                x = 101,
                y = 67,
                name = "Rimuldar north ridge east lane",
                radius = 0,
                route_reset_movement_on_turn_settle = true,
            },
            {x = 100, y = 67, name = "Rimuldar north ridge step", radius = 0, axis_order = {"horizontal", "vertical"}},
            {
                x = 99,
                y = 68,
                name = "Rimuldar north ridge lane",
                radius = 0,
                route_reset_movement_on_turn_settle = true,
            },
            {
                x = 99,
                y = 69,
                name = "Rimuldar north approach bend",
                radius = 0,
                -- Live manual validation needed a sustained Down hold after
                -- the early movement twitch at (99,68); short route presses
                -- exhausted their retry budget without crossing the tile.
                route_hold_after_movement_start_frames = 60,
                route_early_twitch_timeout_frames = 60,
            },
            {x = 98, y = 69, name = "Rimuldar north approach west lane", radius = 0},
            {x = 98, y = 70, name = "Rimuldar north wall corner", radius = 0},
            {
                x = 97,
                y = 71,
                name = "Rimuldar north wall bypass",
                radius = 0,
                -- The south edge at (98,70)->(98,71) is engine-blocked.
                -- Move west onto column 97 before turning south.
                axis_order = {"horizontal", "vertical"},
                route_reset_movement_on_turn_settle = true,
            },
            {x = 97, y = 72, name = "Rimuldar north wall west end", radius = 0},
            {x = 90, y = 72, name = "Rimuldar west lake road", radius = 0},
            {x = 90, y = 71, name = "Rimuldar west lake bend", radius = 0},
            {
                x = 88,
                y = 71,
                name = "Rimuldar lake west road",
                radius = 1,
                warning = "Leaving Rimuldar by the guide's safer west route. Keep HP high for the cave return.",
            },
            {x = 88, y = 58, name = "Safer west route west edge", radius = 0},
            {x = 85, y = 58, name = "South island west pocket lower lane", radius = 0},
            {x = 85, y = 56, name = "South island west pocket bend", radius = 0},
            {x = 83, y = 56, name = "South island west ridge foot", radius = 0},
            {x = 83, y = 54, name = "South island west ridge lane", radius = 0},
            {x = 86, y = 54, name = "South island west ridge east wall", radius = 0},
            {x = 86, y = 52, name = "South island west ridge north bend", radius = 0},
            {x = 92, y = 52, name = "South cave west ridge road", radius = 0},
            {x = 92, y = 48, name = "South cave upper west lane", radius = 0},
            {x = 100, y = 48, name = "South cave upper ridge east end", radius = 0},
            {x = 100, y = 50, name = "South cave lower east bend", radius = 0},
            {x = 104, y = 50, name = "South cave south doorstep", radius = 0},
            {
                x = 104,
                y = 49,
                name = "Swamp Cave South Entrance",
                radius = 0,
                final = true,
                warning = "Swamp Cave opens automatically when you step onto this tile. " ..
                    "If already here, step off and back on, then cross to the north exit.",
            },
        },
    },
    swamp_cave_south_recovery = {
        id = "swamp_cave_south_recovery",
        title = "Swamp Cave South Entrance",
        aliases = {
            "swamp cave south recovery",
            "rimuldar cave notch recovery",
        },
        target_object_ids = {"overworld_swamp_cave_south_entrance"},
        compatible_target_object_ids = {
            "overworld_rainbow_bridge",
            "overworld_charlock_castle",
        },
        destination_maps = {0x15},
        waypoints = {
            {x = 92, y = 57, name = "Blocked mountain notch recovery", radius = 0},
            {x = 90, y = 57, name = "Safer west route north lane", radius = 0},
            {x = 90, y = 58, name = "Safer west route bend", radius = 0},
            {x = 88, y = 58, name = "Safer west route west edge", radius = 0},
            {x = 85, y = 58, name = "South island west pocket lower lane", radius = 0},
            {x = 85, y = 56, name = "South island west pocket bend", radius = 0},
            {x = 83, y = 56, name = "South island west ridge foot", radius = 0},
            {x = 83, y = 54, name = "South island west ridge lane", radius = 0},
            {x = 86, y = 54, name = "South island west ridge east wall", radius = 0},
            {x = 86, y = 52, name = "South island west ridge north bend", radius = 0},
            {x = 92, y = 52, name = "South cave west ridge road", radius = 0},
            {x = 92, y = 48, name = "South cave upper west lane", radius = 0},
            {x = 100, y = 48, name = "South cave upper ridge east end", radius = 0},
            {x = 100, y = 50, name = "South cave lower east bend", radius = 0},
            {x = 104, y = 50, name = "South cave south doorstep", radius = 0},
            {
                x = 104,
                y = 49,
                name = "Swamp Cave South Entrance",
                radius = 0,
                final = true,
                warning = "Return route uses the west-pocket recovery detour to avoid the blocked mountain notch.",
            },
        },
    },
    rainbow_bridge = {
        id = "rainbow_bridge",
        title = "Rainbow Bridge unlock point",
        -- Opt in explicitly so other routes sharing the staging config are
        -- not connected through the hub until they are independently tested.
        continue_after_staging = true,
        aliases = {
            "rainbow bridge",
            "rainbow bridge unlock point",
            "rainbow drop",
            "rainbow drop use point",
        },
        target_object_ids = {"overworld_rainbow_bridge"},
        -- Starting this route at the physical cave landmark must not let a
        -- Travel-object refresh replace it with the Rimuldar return route.
        compatible_target_object_ids = {"overworld_swamp_cave_south_entrance"},
        staging = FINAL_PROGRESSION_STAGING,
        waypoints = {
            {
                x = 104,
                y = 49,
                name = "Swamp Cave South Entrance",
                radius = 0,
                warning = "Rainbow Bridge route. Travel west along the north shore to the Rainbow Drop use point.",
            },
            {x = 93, y = 49, name = "Rainbow Bridge east road", radius = 0},
            {x = 83, y = 49, name = "Rainbow Bridge middle road", radius = 0},
            {x = 73, y = 49, name = "Rainbow Bridge west road", radius = 0},
            {
                x = 70,
                y = 49,
                name = "Rainbow Bridge east inlet shore",
                radius = 0,
                warning = "Detour south around the two-tile water inlet.",
            },
            {x = 70, y = 50, name = "Rainbow Bridge inlet southeast turn", radius = 0},
            {x = 67, y = 50, name = "Rainbow Bridge inlet southwest turn", radius = 0},
            {x = 67, y = 49, name = "Rainbow Bridge peninsula east edge", radius = 0},
            {
                x = 65,
                y = 49,
                name = "Rainbow Bridge unlock point",
                radius = 0,
                final = true,
                warning = "Use the Rainbow Drop here to create the bridge one tile west.",
            },
        },
    },
    rainbow_bridge_return = {
        id = "rainbow_bridge_return",
        title = "Swamp Cave South Entrance",
        -- Cave entry triggers automatically when the hero steps onto the final
        -- tile. Connected itineraries must wait until map 0x15 is observed
        -- before activating the north-exit return.
        staged_handoff_requires_destination_map = true,
        staged_transition_message =
            "Swamp Cave opens automatically when you step onto this tile. " ..
            "If already here, step off and back on, then cross to the north exit.",
        aliases = {
            "rainbow bridge return",
            "return from rainbow bridge",
            "rainbow bridge to swamp cave",
            "rainbow bridge to rimuldar route",
        },
        target_object_ids = {"overworld_swamp_cave_south_entrance"},
        destination_maps = {0x15},
        -- Keep the manually started return active while the physical Rainbow
        -- Bridge landmark remains selected at the route origin.
        compatible_target_object_ids = {"overworld_rainbow_bridge"},
        waypoints = {
            {x = 65, y = 49, name = "Rainbow Bridge unlock point", radius = 0},
            {
                x = 67,
                y = 50,
                name = "Rainbow Bridge inlet southwest turn",
                radius = 0,
                axis_order = {"horizontal", "vertical"},
                -- The formed-bridge eastbound departure can report an early
                -- movement twitch long before the tile coordinate commits.
                -- Keep the press through that cadence, then preserve state
                -- across the south turn at (67,49).
                route_hold_after_movement_start_frames = 60,
                route_early_twitch_timeout_frames = 60,
                route_reset_movement_on_turn_settle = false,
                warning = "Returning east around the two-tile water inlet to the Swamp Cave South Entrance.",
            },
            {x = 70, y = 50, name = "Rainbow Bridge inlet southeast turn", radius = 0},
            {x = 70, y = 49, name = "Rainbow Bridge east inlet shore", radius = 0},
            {x = 73, y = 49, name = "Rainbow Bridge west road", radius = 0},
            {x = 83, y = 49, name = "Rainbow Bridge middle road", radius = 0},
            {x = 93, y = 49, name = "Rainbow Bridge east road", radius = 0},
            {x = 104, y = 49, name = "Swamp Cave South Entrance", radius = 0, final = true},
        },
    },
    charlock_castle = {
        id = "charlock_castle",
        title = "Charlock Castle",
        -- Preserve Charlock as the final destination while the existing
        -- Rimuldar route stages through the Swamp Cave south entrance.
        continue_after_staging = true,
        aliases = {
            "charlock",
            "charlock castle",
            "dragonlord castle",
            "final dungeon",
        },
        target_object_ids = {"overworld_charlock_castle"},
        destination_maps = {0x02},
        compatible_target_object_ids = {
            "overworld_swamp_cave_south_entrance",
            "overworld_rainbow_bridge",
        },
        staging = FINAL_PROGRESSION_STAGING,
        waypoints = {
            {
                x = 103,
                y = 49,
                name = "Swamp Cave south doorstep",
                radius = 0,
                warning = "Charlock Castle route. The Rainbow Drop must already have formed the bridge west of the unlock point.",
            },
            {x = 93, y = 49, name = "Rainbow Bridge east road", radius = 0},
            {x = 83, y = 49, name = "Rainbow Bridge middle road", radius = 0},
            {x = 73, y = 49, name = "Rainbow Bridge west road", radius = 0},
            {x = 70, y = 49, name = "Rainbow Bridge east inlet shore", radius = 0},
            {x = 70, y = 50, name = "Rainbow Bridge inlet southeast turn", radius = 0},
            {x = 67, y = 50, name = "Rainbow Bridge inlet southwest turn", radius = 0},
            {x = 67, y = 49, name = "Rainbow Bridge peninsula east edge", radius = 0},
            {x = 65, y = 49, name = "Rainbow Bridge unlock point", radius = 0},
            {
                x = 63,
                y = 49,
                name = "Charlock island bridge landing",
                radius = 0,
                warning = "Cross west over the Rainbow Bridge onto Charlock island.",
            },
            {x = 61, y = 49, name = "Charlock island northeast shore", radius = 0},
            {x = 58, y = 50, name = "Charlock island upper east lane", radius = 0},
            {x = 58, y = 55, name = "Charlock island east descent", radius = 0},
            {
                x = 57,
                y = 55,
                name = "Charlock island east lower bend",
                radius = 0,
                -- Loaded outbound movement from (58,55) showed an early
                -- twitch, then exhausted the normal cadence retries. A clean
                -- same-origin raw hold completed the west step.
                route_hold_after_movement_start_frames = 60,
                route_early_twitch_timeout_frames = 60,
            },
            {x = 57, y = 56, name = "Charlock island lower east turn", radius = 0},
            {x = 56, y = 56, name = "Charlock island southeast corridor", radius = 0},
            {x = 56, y = 64, name = "Charlock island south road east end", radius = 0},
            {x = 51, y = 64, name = "Charlock island south road west end", radius = 0},
            {x = 52, y = 64, name = "Charlock island southwest lower turn", radius = 0},
            {x = 52, y = 63, name = "Charlock island southwest recovery east", radius = 0},
            {x = 50, y = 63, name = "Charlock island southwest recovery west", radius = 0},
            {x = 50, y = 61, name = "Charlock island west inner turn", radius = 0},
            {
                x = 49,
                y = 61,
                name = "Charlock island west corridor",
                radius = 0,
                -- Loaded outbound movement from (50,61) has the same
                -- slow-entry cadence: bounded retries timed out, while the
                -- unchanged-origin raw hold moved west cleanly.
                route_hold_after_movement_start_frames = 60,
                route_early_twitch_timeout_frames = 60,
            },
            {x = 49, y = 57, name = "Charlock island west rise", radius = 0},
            {x = 51, y = 57, name = "Charlock island central corridor", radius = 0},
            {x = 51, y = 49, name = "Charlock Castle east approach", radius = 0},
            {x = 48, y = 49, name = "Charlock Castle south approach", radius = 0},
            {x = 48, y = 48, name = "Charlock Castle", radius = 0, final = true},
        },
    },
    charlock_return = {
        id = "charlock_return",
        title = "Swamp Cave South Entrance",
        -- Cave entry triggers automatically when the hero steps onto the final
        -- tile. A connected itinerary must wait until map 0x15 is observed;
        -- otherwise it would hand off to the north-exit route while still on
        -- Charlock's side of the cave.
        staged_handoff_requires_destination_map = true,
        staged_transition_message =
            "Swamp Cave opens automatically when you step onto this tile. " ..
            "If already here, step off and back on, then cross to the north exit.",
        aliases = {
            "charlock return",
            "return from charlock",
            "charlock to swamp cave",
            "charlock castle return",
        },
        target_object_ids = {"overworld_swamp_cave_south_entrance"},
        destination_maps = {0x15},
        compatible_target_object_ids = {
            "overworld_charlock_castle",
            "overworld_rainbow_bridge",
        },
        waypoints = {
            {
                x = 48,
                y = 48,
                name = "Charlock Castle",
                radius = 0,
                warning = "Return route to the Swamp Cave South Entrance across the Rainbow Bridge.",
            },
            {x = 48, y = 49, name = "Charlock Castle south approach", radius = 0},
            {x = 51, y = 49, name = "Charlock Castle east approach", radius = 0},
            {x = 51, y = 57, name = "Charlock island central corridor", radius = 0},
            {x = 49, y = 57, name = "Charlock island west rise", radius = 0},
            {x = 49, y = 61, name = "Charlock island west corridor", radius = 0},
            {x = 50, y = 61, name = "Charlock island west inner turn", radius = 0},
            {x = 50, y = 63, name = "Charlock island southwest recovery west", radius = 0},
            {x = 52, y = 63, name = "Charlock island southwest recovery east", radius = 0},
            {x = 52, y = 64, name = "Charlock island southwest lower turn", radius = 0},
            {x = 51, y = 64, name = "Charlock island south road west end", radius = 0},
            {x = 56, y = 64, name = "Charlock island south road east end", radius = 0},
            {x = 56, y = 56, name = "Charlock island southeast corridor", radius = 0},
            {x = 57, y = 56, name = "Charlock island lower east turn", radius = 0},
            {x = 57, y = 55, name = "Charlock island east lower bend", radius = 0},
            {x = 58, y = 55, name = "Charlock island east descent", radius = 0},
            {x = 58, y = 50, name = "Charlock island upper east lane", radius = 0},
            {
                x = 61,
                y = 49,
                name = "Charlock island northeast shore",
                radius = 0,
                axis_order = {"horizontal", "vertical"},
            },
            {x = 63, y = 49, name = "Charlock island bridge landing", radius = 0},
            {x = 65, y = 49, name = "Rainbow Bridge unlock point", radius = 0},
            {
                x = 67,
                y = 50,
                name = "Rainbow Bridge inlet southwest turn",
                radius = 0,
                axis_order = {"horizontal", "vertical"},
                route_hold_after_movement_start_frames = 60,
                route_early_twitch_timeout_frames = 60,
                route_reset_movement_on_turn_settle = false,
            },
            {x = 70, y = 50, name = "Rainbow Bridge inlet southeast turn", radius = 0},
            {x = 70, y = 49, name = "Rainbow Bridge east inlet shore", radius = 0},
            {x = 73, y = 49, name = "Rainbow Bridge west road", radius = 0},
            {x = 83, y = 49, name = "Rainbow Bridge middle road", radius = 0},
            {x = 93, y = 49, name = "Rainbow Bridge east road", radius = 0},
            {x = 104, y = 49, name = "Swamp Cave South Entrance", radius = 0, final = true},
        },
    },
    mountain_cave = {
        id = "mountain_cave",
        title = "Mountain Cave",
        aliases = {
            "mountain cave",
            "rock mountain cave",
            "rocky mountain cave",
            "bonus dungeon",
        },
        target_object_ids = {"overworld_mountain_cave"},
        destination_maps = {0x16, 0x17},
        staging = MOUNTAIN_CAVE_STAGING,
        waypoints = {
            {
                x = 18,
                y = 64,
                name = "Western desert east road",
                radius = 0,
                warning = "Mountain Cave spur. Follow the forest corridor north, then approach the cave from the west.",
            },
            {x = 16, y = 64, name = "Mountain Cave forest turn", radius = 0},
            {x = 16, y = 58, name = "Mountain Cave west forest lane", radius = 0},
            {x = 25, y = 58, name = "Mountain Cave south approach", radius = 0},
            {x = 25, y = 57, name = "Mountain Cave west approach", radius = 0},
            {x = 29, y = 57, name = "Mountain Cave", radius = 0, final = true},
        },
    },
    mountain_cave_return = {
        id = "mountain_cave_return",
        title = "Western desert east road",
        -- Keep the manually selected return route active while the physical
        -- cave remains selected after Travel-object refreshes at nearby
        -- waypoints. This compatibility binding does not make the return route
        -- eligible to start from an ordinary Mountain Cave selection.
        compatible_target_object_ids = {"overworld_mountain_cave"},
        aliases = {
            "mountain cave return",
            "return from mountain cave",
            "mountain cave to western desert",
            "mountain cave to hauksness route",
        },
        waypoints = {
            {x = 29, y = 57, name = "Mountain Cave", radius = 0},
            {
                x = 25,
                y = 57,
                name = "Mountain Cave west approach",
                radius = 0,
                warning = "Returning to the Hauksness route at Western desert east road.",
            },
            {x = 25, y = 58, name = "Mountain Cave south approach", radius = 0},
            {x = 16, y = 58, name = "Mountain Cave west forest lane", radius = 0},
            {x = 16, y = 64, name = "Mountain Cave forest turn", radius = 0},
            {x = 18, y = 64, name = "Western desert east road", radius = 0, final = true},
        },
    },
    hauksness = {
        id = "hauksness",
        title = "Hauksness",
        aliases = {
            "hauksness",
            "haukness",
            "damdara",
            "ruins of hauksness",
            "ruined town",
            "destroyed town",
        },
        target_object_ids = {"overworld_hauksness"},
        destination_maps = {0x03},
        staging = HAUKSNESS_STAGING,
        waypoints = {
            {x = 104, y = 10, name = "Kol", radius = 1},
            {x = 96, y = 13, name = "Kol forest west edge", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 96, y = 21, name = "West of Kol north lane", radius = 1},
            {x = 98, y = 26, name = "Kol south road east detour", radius = 0, axis_order = {"vertical", "horizontal"}},
            {x = 98, y = 32, name = "Kol south road lower east lane", radius = 0},
            {x = 96, y = 32, name = "Kol south road", radius = 1},
            {x = 96, y = 35, name = "Kol south road east lane", radius = 0},
            {x = 93, y = 35, name = "Kol south road lower bend", radius = 0},
            {x = 93, y = 36, name = "Kol south road bend", radius = 0},
            {x = 92, y = 36, name = "Kol lower south lane", radius = 0},
            {x = 92, y = 37, name = "Kol bridge east lane", radius = 0},
            {x = 90, y = 37, name = "Kol southwest bridge", radius = 0},
            {x = 84, y = 26, name = "Kol southwest track", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 74, y = 18, name = "North Alefgard bridge road", radius = 1, axis_order = {"horizontal", "vertical"}},
            {
                x = 61,
                y = 18,
                name = "Northeast bridge",
                radius = 1,
                axis_order = {"horizontal", "vertical"},
                warning = "Northeast bridge crossing. Monsters should become safer beyond this point.",
            },
            {x = 61, y = 19, name = "Northeast bridge south lane", radius = 0},
            {x = 59, y = 19, name = "Northeast bridge lower west lane", radius = 0},
            {x = 58, y = 18, name = "Northeast bridge west bend", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 54, y = 15, name = "Northeast bridge west approach", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 45, y = 13, name = "North Alefgard east road", radius = 1, axis_order = {"vertical", "horizontal"}},
            {x = 35, y = 13, name = "North Alefgard west road", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 28, y = 13, name = "Erdrick's Cave road", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 23, y = 13, name = "Cave road south lane", radius = 1},
            {x = 23, y = 11, name = "Cave road west lane", radius = 0},
            {x = 21, y = 11, name = "Cave road north edge", radius = 0},
            {x = 21, y = 10, name = "Garinham field road bend", radius = 0},
            {x = 20, y = 9, name = "Garinham east field", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 20, y = 7, name = "Garinham field east lane", radius = 0},
            {x = 19, y = 6, name = "Garinham ridge entry", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 16, y = 6, name = "Garinham east ridge", radius = 0},
            {x = 16, y = 5, name = "Garinham shoulder bend", radius = 0},
            {x = 15, y = 4, name = "Garinham shoulder east step", radius = 0},
            {x = 14, y = 4, name = "Garinham mountain shoulder", radius = 0},
            {x = 14, y = 3, name = "Garinham north coast lane", radius = 0},
            {x = 8, y = 3, name = "Garinham north coast west lane", radius = 1},
            {x = 5, y = 4, name = "Garinham outskirts", radius = 1},
            {x = 7, y = 4, name = "Hauksness north road", radius = 0},
            {x = 7, y = 6, name = "Hauksness ridge upper lip", radius = 0},
            {x = 5, y = 6, name = "Hauksness ridge west turn", radius = 0},
            {x = 5, y = 7, name = "Hauksness ridge west notch", radius = 0},
            {x = 3, y = 7, name = "Hauksness ridge west gap", radius = 0},
            {x = 3, y = 12, name = "Hauksness ridge lower coast", radius = 0},
            {x = 4, y = 12, name = "Hauksness coast east step", radius = 0},
            {x = 4, y = 13, name = "Hauksness coast south step", radius = 0},
            {x = 5, y = 13, name = "Hauksness coast lower east step", radius = 0},
            {x = 5, y = 14, name = "Hauksness coast lower bend", radius = 0},
            {x = 7, y = 14, name = "Hauksness northern descent", radius = 1},
            {x = 15, y = 14, name = "Western desert east shelf", radius = 0, axis_order = {"horizontal", "vertical"}},
            {
                x = 15,
                y = 28,
                name = "Western desert south shelf",
                radius = 0,
                axis_order = {"horizontal", "vertical"},
                warning = "Hauksness route. Strong monsters ahead; keep HP high.",
            },
            {x = 13, y = 28, name = "Western desert west detour", radius = 0},
            {x = 13, y = 30, name = "Western desert south detour", radius = 0},
            {x = 11, y = 30, name = "Western desert lower west lane", radius = 0},
            {x = 11, y = 31, name = "Western desert lower notch", radius = 0},
            {x = 9, y = 31, name = "Western desert west notch", radius = 0},
            {x = 8, y = 31, name = "Western desert vertical pass", radius = 0},
            {x = 8, y = 34, name = "Western desert pass foot", radius = 1},
            {x = 8, y = 51, name = "Western desert long descent", radius = 0},
            {x = 6, y = 51, name = "Western desert row 51 west bend", radius = 0},
            {x = 6, y = 52, name = "Western desert row 52 bend", radius = 0},
            {x = 4, y = 52, name = "Western desert row 52 west lane", radius = 0},
            {x = 4, y = 54, name = "Western desert lower shelf", radius = 0},
            {x = 2, y = 54, name = "Western desert west wall", radius = 0},
            {x = 2, y = 64, name = "Western desert south road", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 18, y = 64, name = "Western desert east road", radius = 0},
            {x = 18, y = 69, name = "Western desert southeast bend", radius = 0},
            {x = 29, y = 69, name = "Hauksness outer road", radius = 1},
            {x = 29, y = 82, name = "Hauksness north ridge", radius = 0},
            {x = 31, y = 81, name = "Hauksness northwest bend", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 26, y = 81, name = "Hauksness western ridge", radius = 0},
            {x = 26, y = 79, name = "Hauksness ridge rise", radius = 0},
            {x = 22, y = 79, name = "Hauksness west road", radius = 0},
            {x = 22, y = 83, name = "Hauksness west road south turn", radius = 0},
            {x = 20, y = 83, name = "Hauksness southwest shelf", radius = 0},
            {x = 20, y = 85, name = "Hauksness southwest lower bend", radius = 0},
            {x = 18, y = 85, name = "Hauksness western wall", radius = 0},
            {x = 16, y = 85, name = "Hauksness west lower lane", radius = 0},
            {x = 16, y = 86, name = "Hauksness west lower bend", radius = 0},
            {x = 15, y = 86, name = "Hauksness west approach north", radius = 0},
            {x = 15, y = 88, name = "Hauksness west approach lower lane", radius = 0},
            {
                x = 26,
                y = 88,
                name = "Hauksness lower east lane",
                radius = 0,
                warning = "Hauksness ruins are very dangerous. Be ready for strong encounters.",
            },
            {x = 26, y = 90, name = "Hauksness lower south bend", radius = 0},
            {x = 26, y = 91, name = "Hauksness lower pocket", radius = 0},
            {x = 24, y = 91, name = "Hauksness lower west pocket", radius = 0},
            {x = 24, y = 93, name = "Hauksness lower west drop", radius = 0},
            {x = 15, y = 93, name = "Hauksness lower west lane", radius = 0},
            {x = 15, y = 89, name = "Hauksness west approach", radius = 0},
            {x = 24, y = 89, name = "Hauksness doorstep west", radius = 0},
            {x = 25, y = 89, name = "Hauksness", radius = 0, final = true},
        },
    },
    hauksness_cantlin = {
        id = "hauksness_cantlin",
        title = "Hauksness",
        aliases = {
            "hauksness from cantlin",
            "cantlin to hauksness",
            "return from cantlin",
        },
        target_object_ids = {"overworld_hauksness"},
        destination_maps = {0x03},
        staging = HAUKSNESS_STAGING,
        -- Auto-selection ends before the strict Hauksness doorstep and entry.
        selection_max_index = 56,
        waypoints = {
            {x = 73, y = 102, name = "Cantlin", radius = 0},
            {
                x = 73,
                y = 91,
                name = "Cantlin north road",
                radius = 0,
                warning = "Cantlin return to Hauksness. Strong monsters remain throughout the western route; keep HP high.",
            },
            {x = 68, y = 91, name = "Cantlin northwest turn", radius = 0},
            {x = 68, y = 92, name = "Upper forest south notch", radius = 0},
            {x = 64, y = 92, name = "Upper forest west lane", radius = 0},
            {x = 64, y = 93, name = "Upper forest second south notch", radius = 0},
            {x = 60, y = 93, name = "Upper forest middle lane", radius = 0},
            {x = 60, y = 94, name = "Upper forest third south notch", radius = 0},
            {x = 56, y = 94, name = "Upper forest lower lane", radius = 0},
            {x = 56, y = 95, name = "Upper forest lower drop", radius = 0},
            {x = 54, y = 95, name = "Western forest shelf", radius = 0},
            {x = 54, y = 96, name = "Western forest first drop", radius = 0},
            {x = 53, y = 96, name = "Western forest first west step", radius = 0},
            {x = 53, y = 97, name = "Western forest second drop", radius = 0},
            {x = 52, y = 97, name = "Western forest second west step", radius = 0},
            {x = 52, y = 98, name = "Western forest third drop", radius = 0},
            {x = 51, y = 98, name = "Western forest third west step", radius = 0},
            {x = 51, y = 99, name = "Western forest fourth drop", radius = 0},
            {x = 50, y = 99, name = "Western forest fourth west step", radius = 0},
            {x = 50, y = 100, name = "Western forest fifth drop", radius = 0},
            {x = 49, y = 100, name = "Western forest fifth west step", radius = 0},
            {x = 49, y = 102, name = "Western forest long drop", radius = 0},
            {x = 48, y = 102, name = "Western forest sixth west step", radius = 0},
            {x = 48, y = 104, name = "Western forest second long drop", radius = 0},
            {x = 47, y = 104, name = "Western forest seventh west step", radius = 0},
            {x = 47, y = 105, name = "Western forest seventh drop", radius = 0},
            {x = 45, y = 105, name = "Western forest eighth west lane", radius = 0},
            {x = 45, y = 106, name = "Western forest eighth drop", radius = 0},
            {x = 44, y = 106, name = "Western forest ninth west step", radius = 0},
            {x = 44, y = 107, name = "Western forest ninth drop", radius = 0},
            {x = 43, y = 107, name = "Western forest tenth west step", radius = 0},
            {x = 43, y = 108, name = "Western forest tenth drop", radius = 0},
            {x = 42, y = 108, name = "Western forest eleventh west step", radius = 0},
            {x = 42, y = 111, name = "Southern forest long drop", radius = 0},
            {x = 41, y = 111, name = "Southern forest first west step", radius = 0},
            {x = 41, y = 112, name = "Southern forest first drop", radius = 0},
            {x = 40, y = 112, name = "Southern forest second west step", radius = 0},
            {x = 40, y = 113, name = "Southern forest second drop", radius = 0},
            {x = 39, y = 113, name = "Southern forest third west step", radius = 0},
            {x = 39, y = 114, name = "Southern forest third drop", radius = 0},
            {x = 38, y = 114, name = "Southern forest fourth west step", radius = 0},
            {x = 38, y = 115, name = "Southern forest fourth drop", radius = 0},
            {x = 36, y = 115, name = "Southern forest fifth west lane", radius = 0},
            {x = 36, y = 116, name = "Southern forest fifth drop", radius = 0},
            {x = 33, y = 116, name = "Southern forest sixth west lane", radius = 0},
            {x = 33, y = 117, name = "Southern forest lower drop", radius = 0},
            {x = 21, y = 117, name = "Southern forest long west lane", radius = 0},
            {x = 21, y = 116, name = "Southern forest northwest rise", radius = 0},
            {x = 20, y = 116, name = "Southern forest northwest step", radius = 0},
            {x = 20, y = 108, name = "Hauksness south road rise", radius = 0},
            {x = 22, y = 108, name = "Hauksness south road east lane", radius = 0},
            {x = 22, y = 107, name = "Hauksness south road north step", radius = 0},
            {x = 23, y = 107, name = "Hauksness south road second east step", radius = 0},
            {x = 23, y = 95, name = "Hauksness western corridor", radius = 0},
            {x = 22, y = 95, name = "Hauksness western corridor west step", radius = 0},
            {
                x = 22,
                y = 89,
                name = "Hauksness west approach",
                radius = 0,
                warning = "Hauksness ruins are very dangerous. Be ready for strong encounters.",
            },
            {x = 24, y = 89, name = "Hauksness doorstep west", radius = 0},
            {x = 25, y = 89, name = "Hauksness", radius = 0, final = true},
        },
    },
    cantlin_hauksness = {
        id = "cantlin_hauksness",
        title = "Cantlin",
        aliases = {
            "cantlin",
            "cantlin town",
            "cantlin from hauksness",
            "hauksness to cantlin",
            "return to cantlin",
        },
        target_object_ids = {"overworld_cantlin"},
        destination_maps = {0x0A},
        staging = CANTLIN_STAGING,
        waypoints = {
            {x = 25, y = 89, name = "Hauksness", radius = 0},
            {
                x = 24,
                y = 89,
                name = "Hauksness doorstep west",
                radius = 0,
                warning = "Hauksness route to Cantlin. Strong monsters remain throughout the eastern route; keep HP high.",
            },
            {x = 22, y = 89, name = "Hauksness west approach", radius = 0},
            {x = 22, y = 95, name = "Hauksness western corridor south lane", radius = 0},
            {x = 23, y = 95, name = "Hauksness western corridor east step", radius = 0},
            {x = 23, y = 107, name = "Hauksness south corridor", radius = 0},
            {x = 22, y = 107, name = "Hauksness south road west step", radius = 0},
            {x = 22, y = 108, name = "Hauksness south road south step", radius = 0},
            {x = 20, y = 108, name = "Hauksness south road west lane", radius = 0},
            {x = 20, y = 116, name = "Southern forest northwest entry", radius = 0},
            {x = 21, y = 116, name = "Southern forest first east step", radius = 0},
            {x = 21, y = 117, name = "Southern forest lower lane", radius = 0},
            {x = 33, y = 117, name = "Southern forest long east lane", radius = 0},
            {x = 33, y = 116, name = "Southern forest first rise", radius = 0},
            {x = 36, y = 116, name = "Southern forest second east lane", radius = 0},
            {x = 36, y = 115, name = "Southern forest second rise", radius = 0},
            {x = 38, y = 115, name = "Southern forest third east lane", radius = 0},
            {x = 38, y = 114, name = "Southern forest third rise", radius = 0},
            {x = 39, y = 114, name = "Southern forest fourth east step", radius = 0},
            {x = 39, y = 113, name = "Southern forest fourth rise", radius = 0},
            {x = 40, y = 113, name = "Southern forest fifth east step", radius = 0},
            {x = 40, y = 112, name = "Southern forest fifth rise", radius = 0},
            {x = 41, y = 112, name = "Southern forest sixth east step", radius = 0},
            {x = 41, y = 111, name = "Southern forest sixth rise", radius = 0},
            {x = 42, y = 111, name = "Southern forest seventh east step", radius = 0},
            {x = 42, y = 108, name = "Southern forest long rise", radius = 0},
            {x = 43, y = 108, name = "Western forest first east step", radius = 0},
            {x = 43, y = 107, name = "Western forest first rise", radius = 0},
            {x = 44, y = 107, name = "Western forest second east step", radius = 0},
            {x = 44, y = 106, name = "Western forest second rise", radius = 0},
            {x = 45, y = 106, name = "Western forest third east step", radius = 0},
            {x = 45, y = 105, name = "Western forest third rise", radius = 0},
            {x = 47, y = 105, name = "Western forest fourth east lane", radius = 0},
            {x = 47, y = 104, name = "Western forest fourth rise", radius = 0},
            {x = 48, y = 104, name = "Western forest fifth east step", radius = 0},
            {x = 48, y = 102, name = "Western forest first long rise", radius = 0},
            {x = 49, y = 102, name = "Western forest sixth east step", radius = 0},
            {x = 49, y = 100, name = "Western forest second long rise", radius = 0},
            {x = 50, y = 100, name = "Western forest seventh east step", radius = 0},
            {
                x = 50,
                y = 99,
                name = "Western forest seventh rise",
                radius = 0,
                -- Live reverse-route entry from (50,100) can twitch before the
                -- north step commits. Keep the press held through completion.
                route_hold_after_movement_start_frames = 60,
                route_early_twitch_timeout_frames = 60,
                route_reset_movement_on_turn_settle = false,
            },
            {x = 50, y = 98, name = "Western forest north carry", radius = 0},
            {x = 52, y = 98, name = "Western forest ninth east step", radius = 0},
            {x = 52, y = 97, name = "Western forest ninth rise", radius = 0},
            {x = 53, y = 97, name = "Western forest tenth east step", radius = 0},
            {x = 53, y = 96, name = "Western forest tenth rise", radius = 0},
            {x = 54, y = 96, name = "Western forest eleventh east step", radius = 0},
            {x = 54, y = 95, name = "Western forest final rise", radius = 0},
            {x = 56, y = 95, name = "Upper forest first east lane", radius = 0},
            {x = 56, y = 94, name = "Upper forest first rise", radius = 0},
            {x = 60, y = 94, name = "Upper forest middle east lane", radius = 0},
            {x = 60, y = 93, name = "Upper forest second rise", radius = 0},
            {x = 64, y = 93, name = "Upper forest upper east lane", radius = 0},
            {
                x = 64,
                y = 92,
                name = "Upper forest third rise",
                radius = 0,
                -- The north entry completes late and naturally carries onto
                -- the validated upper lane at (64,91).
                route_hold_after_movement_start_frames = 60,
                route_early_twitch_timeout_frames = 60,
                route_reset_movement_on_turn_settle = false,
            },
            {x = 64, y = 91, name = "Upper forest north carry", radius = 0},
            {x = 68, y = 91, name = "Cantlin northwest turn", radius = 0},
            {x = 73, y = 91, name = "Cantlin north road", radius = 0},
            {
                x = 73,
                y = 102,
                name = "Cantlin",
                radius = 0,
                final = true,
                axis_order = {"horizontal", "vertical"},
            },
        },
    },
    great_swamp_cantlin = {
        id = "great_swamp_cantlin",
        title = "Eastern Great Swamp Search Area",
        aliases = {
            "great swamp search area",
            "eastern great swamp",
            "great swamp from cantlin",
            "cantlin to great swamp",
        },
        target_object_ids = {
            "overworld_eastern_great_swamp_search_area",
        },
        staging = GREAT_SWAMP_STAGING,
        waypoints = {
            {x = 73, y = 102, name = "Cantlin", radius = 0},
            {
                x = 73,
                y = 91,
                name = "Cantlin north road",
                radius = 0,
                warning = "Eastern Great Swamp route. Strong monsters remain throughout the southern route; keep HP high.",
            },
            {x = 68, y = 91, name = "Cantlin northwest turn", radius = 0},
            {x = 68, y = 92, name = "Upper forest south notch", radius = 0},
            {x = 64, y = 92, name = "Upper forest west lane", radius = 0},
            {x = 64, y = 93, name = "Upper forest second south notch", radius = 0},
            {x = 60, y = 93, name = "Upper forest middle lane", radius = 0},
            {x = 60, y = 94, name = "Upper forest third south notch", radius = 0},
            {x = 56, y = 94, name = "Upper forest lower lane", radius = 0},
            {x = 56, y = 95, name = "Upper forest lower drop", radius = 0},
            {x = 54, y = 95, name = "Western forest shelf", radius = 0},
            {x = 54, y = 96, name = "Western forest first drop", radius = 0},
            {x = 53, y = 96, name = "Western forest first west step", radius = 0},
            {x = 53, y = 97, name = "Western forest second drop", radius = 0},
            {x = 52, y = 97, name = "Western forest second west step", radius = 0},
            {x = 52, y = 98, name = "Western forest third drop", radius = 0},
            {x = 51, y = 98, name = "Western forest third west step", radius = 0},
            {x = 51, y = 99, name = "Western forest fourth drop", radius = 0},
            {x = 50, y = 99, name = "Western forest fourth west step", radius = 0},
            {x = 50, y = 100, name = "Western forest fifth drop", radius = 0},
            {x = 49, y = 100, name = "Western forest fifth west step", radius = 0},
            {x = 49, y = 102, name = "Western forest long drop", radius = 0},
            {x = 48, y = 102, name = "Western forest sixth west step", radius = 0},
            {x = 48, y = 104, name = "Western forest second long drop", radius = 0},
            {x = 59, y = 104, name = "Southern plains west road", radius = 0},
            {x = 59, y = 105, name = "Southern plains first drop", radius = 0},
            {x = 63, y = 105, name = "Southern plains middle road", radius = 0},
            {x = 63, y = 106, name = "Southern plains second drop", radius = 0},
            {x = 64, y = 106, name = "Southern plains east step", radius = 0},
            {x = 64, y = 108, name = "Southern plains long drop", radius = 0},
            {x = 66, y = 108, name = "Great Swamp northwest road", radius = 0},
            {x = 66, y = 110, name = "Great Swamp northwest drop", radius = 0},
            {x = 72, y = 110, name = "Great Swamp north road", radius = 0},
            {x = 72, y = 112, name = "Great Swamp north descent", radius = 0},
            {
                x = 74,
                y = 112,
                name = "Great Swamp west lip",
                radius = 0,
                warning = "Great Swamp ahead. Keep HP high and be ready for strong encounters.",
            },
            {x = 74, y = 113, name = "Great Swamp west entry", radius = 0},
            {x = 89, y = 113, name = "Great Swamp east lane", radius = 0},
            {
                x = 89,
                y = 112,
                name = "Eastern Great Swamp Search Area",
                radius = 0,
                final = true,
                warning = "Use Gwaelin's Love and Search to continue.",
            },
        },
    },
    cantlin_great_swamp = {
        id = "cantlin_great_swamp",
        title = "Cantlin",
        aliases = {
            "great swamp to cantlin",
            "cantlin from great swamp",
            "return to cantlin from great swamp",
        },
        target_object_ids = {"overworld_cantlin"},
        staging = CANTLIN_STAGING,
        waypoints = {
            {x = 89, y = 112, name = "Eastern Great Swamp Search Area", radius = 0},
            {
                x = 89,
                y = 113,
                name = "Great Swamp east lane",
                radius = 0,
                warning = "Returning to Cantlin. Strong monsters remain throughout the northern route; keep HP high.",
            },
            {x = 75, y = 113, name = "Great Swamp middle lane", radius = 0},
            {x = 73, y = 113, name = "Great Swamp west lane", radius = 0},
            {x = 73, y = 111, name = "Great Swamp west rise", radius = 0},
            {x = 71, y = 111, name = "Great Swamp northwest step", radius = 0},
            {x = 71, y = 110, name = "Great Swamp northwest rise", radius = 0},
            {x = 65, y = 110, name = "Great Swamp north westbound road", radius = 0},
            {x = 65, y = 108, name = "Great Swamp north rise", radius = 0},
            {x = 63, y = 108, name = "Southern plains east return", radius = 0},
            {x = 63, y = 106, name = "Southern plains east rise", radius = 0},
            {x = 63, y = 105, name = "Southern plains upper rise", radius = 0},
            {x = 59, y = 105, name = "Southern plains westbound road", radius = 0},
            {x = 59, y = 104, name = "Southern plains west rise", radius = 0},
            {x = 48, y = 104, name = "Western forest return anchor", radius = 0},
            {x = 48, y = 102, name = "Western forest first long rise", radius = 0},
            {x = 49, y = 102, name = "Western forest sixth east step", radius = 0},
            {x = 49, y = 100, name = "Western forest second long rise", radius = 0},
            {x = 50, y = 100, name = "Western forest seventh east step", radius = 0},
            {
                x = 50,
                y = 99,
                name = "Western forest seventh rise",
                radius = 0,
                route_hold_after_movement_start_frames = 60,
                route_early_twitch_timeout_frames = 60,
                route_reset_movement_on_turn_settle = false,
            },
            {x = 50, y = 98, name = "Western forest north carry", radius = 0},
            {x = 52, y = 98, name = "Western forest ninth east step", radius = 0},
            {x = 52, y = 97, name = "Western forest ninth rise", radius = 0},
            {x = 53, y = 97, name = "Western forest tenth east step", radius = 0},
            {x = 53, y = 96, name = "Western forest tenth rise", radius = 0},
            {x = 54, y = 96, name = "Western forest eleventh east step", radius = 0},
            {x = 54, y = 95, name = "Western forest final rise", radius = 0},
            {x = 56, y = 95, name = "Upper forest first east lane", radius = 0},
            {x = 56, y = 94, name = "Upper forest first rise", radius = 0},
            {x = 60, y = 94, name = "Upper forest middle east lane", radius = 0},
            {x = 60, y = 93, name = "Upper forest second rise", radius = 0},
            {x = 64, y = 93, name = "Upper forest upper east lane", radius = 0},
            {
                x = 64,
                y = 92,
                name = "Upper forest third rise",
                radius = 0,
                route_hold_after_movement_start_frames = 60,
                route_early_twitch_timeout_frames = 60,
                route_reset_movement_on_turn_settle = false,
            },
            {x = 64, y = 91, name = "Upper forest north carry", radius = 0},
            {x = 68, y = 91, name = "Cantlin northwest turn", radius = 0},
            {x = 73, y = 91, name = "Cantlin north road", radius = 0},
            {
                x = 73,
                y = 102,
                name = "Cantlin",
                radius = 0,
                final = true,
                axis_order = {"horizontal", "vertical"},
            },
        },
    },
    kol_hauksness = {
        id = "kol_hauksness",
        title = "Kol",
        aliases = {
            "kol from hauksness",
            "hauksness to kol",
            "return from hauksness",
        },
        target_object_ids = {"overworld_kol"},
        destination_maps = {0x07},
        -- Auto-selection ends at Garinham; an active route still retains the full chain to Kol.
        selection_max_index = 54,
        waypoints = {
            {x = 25, y = 89, name = "Hauksness", radius = 1},
            {
                x = 24,
                y = 89,
                name = "Hauksness doorstep west",
                radius = 0,
                warning = "Hauksness return to Kol. Strong monsters remain nearby; keep HP high.",
            },
            {x = 15, y = 89, name = "Hauksness west approach", radius = 0},
            {x = 15, y = 93, name = "Hauksness lower west lane", radius = 0},
            {x = 24, y = 93, name = "Hauksness lower west drop", radius = 0},
            {
                x = 24,
                y = 91,
                name = "Hauksness lower west pocket",
                radius = 0,
                axis_order = {"horizontal", "vertical"},
            },
            {x = 26, y = 91, name = "Hauksness lower pocket", radius = 0},
            {x = 26, y = 90, name = "Hauksness lower south bend", radius = 0},
            {x = 26, y = 88, name = "Hauksness lower east lane", radius = 0},
            {x = 15, y = 88, name = "Hauksness west approach lower lane", radius = 0},
            {x = 15, y = 86, name = "Hauksness west approach north", radius = 0},
            {x = 16, y = 86, name = "Hauksness west lower bend", radius = 0},
            {x = 16, y = 85, name = "Hauksness west lower lane", radius = 0},
            {x = 18, y = 85, name = "Hauksness western wall", radius = 0},
            {x = 20, y = 85, name = "Hauksness southwest lower bend", radius = 0},
            {x = 20, y = 83, name = "Hauksness southwest shelf", radius = 0},
            {x = 22, y = 83, name = "Hauksness west road south turn", radius = 0},
            {x = 22, y = 79, name = "Hauksness west road", radius = 0},
            {x = 26, y = 79, name = "Hauksness ridge rise", radius = 0},
            {x = 26, y = 81, name = "Hauksness western ridge", radius = 0},
            {x = 31, y = 81, name = "Hauksness northwest bend", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 29, y = 82, name = "Hauksness north ridge", radius = 0},
            {x = 29, y = 69, name = "Hauksness outer road", radius = 1},
            {x = 18, y = 69, name = "Western desert southeast bend", radius = 0},
            {x = 18, y = 64, name = "Western desert east road", radius = 0},
            {x = 2, y = 64, name = "Western desert south road", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 2, y = 54, name = "Western desert west wall", radius = 0},
            {x = 4, y = 54, name = "Western desert lower shelf", radius = 0},
            {x = 4, y = 52, name = "Western desert row 52 west lane", radius = 0},
            {x = 6, y = 52, name = "Western desert row 52 bend", radius = 0},
            {x = 6, y = 51, name = "Western desert row 51 west bend", radius = 0},
            {x = 8, y = 51, name = "Western desert long descent", radius = 0},
            {x = 8, y = 34, name = "Western desert pass foot", radius = 1},
            {x = 8, y = 31, name = "Western desert vertical pass", radius = 0},
            {x = 9, y = 31, name = "Western desert west notch", radius = 0},
            {x = 11, y = 31, name = "Western desert lower notch", radius = 0},
            {x = 11, y = 30, name = "Western desert lower west lane", radius = 0},
            {x = 13, y = 30, name = "Western desert south detour", radius = 0},
            {x = 13, y = 28, name = "Western desert west detour", radius = 0},
            {x = 15, y = 28, name = "Western desert south shelf", radius = 0, axis_order = {"horizontal", "vertical"}},
            {
                x = 15,
                y = 14,
                name = "Western desert east shelf",
                radius = 0,
                axis_order = {"horizontal", "vertical"},
                warning = "Leaving the western desert. Monsters should become safer ahead.",
            },
            {x = 7, y = 14, name = "Hauksness northern descent", radius = 1},
            {x = 5, y = 14, name = "Hauksness coast lower bend", radius = 0},
            {x = 5, y = 13, name = "Hauksness coast lower east step", radius = 0},
            {x = 4, y = 13, name = "Hauksness coast south step", radius = 0},
            {x = 4, y = 12, name = "Hauksness coast east step", radius = 0},
            {x = 3, y = 12, name = "Hauksness ridge lower coast", radius = 0},
            {x = 3, y = 7, name = "Hauksness ridge west gap", radius = 0},
            {x = 5, y = 7, name = "Hauksness ridge west notch", radius = 0},
            {x = 5, y = 6, name = "Hauksness ridge west turn", radius = 0},
            {x = 7, y = 6, name = "Hauksness ridge upper lip", radius = 0},
            {x = 7, y = 4, name = "Hauksness north road", radius = 0},
            {x = 5, y = 4, name = "Garinham outskirts", radius = 1},
            {x = 8, y = 3, name = "Garinham north coast west lane", radius = 1},
            {x = 14, y = 3, name = "Garinham north coast lane", radius = 0},
            {x = 14, y = 4, name = "Garinham mountain shoulder", radius = 0},
            {x = 15, y = 4, name = "Garinham shoulder east step", radius = 0},
            {x = 16, y = 5, name = "Garinham shoulder bend", radius = 0},
            {x = 16, y = 6, name = "Garinham east ridge", radius = 0},
            {x = 19, y = 6, name = "Garinham ridge entry", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 20, y = 7, name = "Garinham field east lane", radius = 0},
            {x = 20, y = 9, name = "Garinham east field", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 21, y = 10, name = "Garinham field road bend", radius = 0},
            {x = 21, y = 11, name = "Cave road north edge", radius = 0},
            {x = 23, y = 11, name = "Cave road west lane", radius = 0},
            {x = 23, y = 13, name = "Cave road south lane", radius = 1},
            {x = 28, y = 13, name = "Erdrick's Cave road", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 35, y = 13, name = "North Alefgard west road", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 45, y = 13, name = "North Alefgard east road", radius = 1, axis_order = {"vertical", "horizontal"}},
            {x = 54, y = 15, name = "Northeast bridge west approach", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 58, y = 18, name = "Northeast bridge west bend", radius = 0, axis_order = {"vertical", "horizontal"}},
            {x = 59, y = 19, name = "Northeast bridge lower west lane", radius = 0},
            {x = 61, y = 19, name = "Northeast bridge south lane", radius = 0},
            {x = 61, y = 18, name = "Northeast bridge", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 74, y = 18, name = "North Alefgard bridge road", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 84, y = 26, name = "Kol southwest track", radius = 1, axis_order = {"vertical", "horizontal"}},
            {x = 90, y = 37, name = "Kol southwest bridge", radius = 0},
            {x = 92, y = 37, name = "Kol bridge east lane", radius = 0},
            {x = 92, y = 36, name = "Kol lower south lane", radius = 0},
            {x = 93, y = 36, name = "Kol south road bend", radius = 0},
            {x = 93, y = 35, name = "Kol south road lower bend", radius = 0},
            {x = 96, y = 35, name = "Kol south road east lane", radius = 0},
            {x = 96, y = 32, name = "Kol south road", radius = 1},
            {x = 98, y = 32, name = "Kol south road lower east lane", radius = 0},
            {x = 98, y = 26, name = "Kol south road east detour", radius = 0, axis_order = {"vertical", "horizontal"}},
            {x = 96, y = 21, name = "West of Kol north lane", radius = 1},
            {x = 96, y = 13, name = "Kol forest west edge", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 104, y = 10, name = "Kol", radius = 0, final = true},
        },
    },
    erdrick = {
        id = "erdrick",
        title = "Erdrick's Cave",
        aliases = {"erdrick", "erdricks cave", "erdrick cave", "erdric", "erdric cave", "cave"},
        target_object_ids = {"overworld_erdrick_s_cave"},
        destination_maps = {0x1C, 0x1D},
        waypoints = {
            {x = 43, y = 43, name = "Tantegel Castle road", radius = 1},
            {x = 47, y = 41, name = "Brecconary west bypass", radius = 0},
            {
                x = 44,
                y = 38,
                name = "Bridge south bend",
                radius = 1,
                warning = "Bridge crossing. Monsters may become more dangerous beyond this point.",
            },
            {x = 38, y = 36, name = "Bridge lower west lane", radius = 0},
            {x = 38, y = 34, name = "Bridge west bend", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 38, y = 32, name = "Upper bridge lane", radius = 0},
            {x = 35, y = 32, name = "East choke approach", radius = 0},
            {x = 35, y = 24, name = "Eastern mountain lane", radius = 0},
            {x = 32, y = 19, name = "North ridge bend", radius = 1},
            {x = 28, y = 20, name = "North trail marker", radius = 1},
            {x = 28, y = 12, name = "Erdrick's Cave", radius = 0, final = true},
        },
    },
    tantegel = {
        id = "tantegel",
        title = "Tantegel Castle",
        aliases = {"tantegel", "tantegel castle", "castle"},
        target_object_ids = {"overworld_tantegel_castle"},
        destination_maps = {0x04, 0x05},
        waypoints = {
            {x = 2, y = 2, name = "Garinham road", radius = 1},
            {x = 5, y = 4, name = "Garinham outskirts", radius = 1},
            {x = 8, y = 3, name = "Garinham north coast west lane", radius = 1},
            {x = 14, y = 3, name = "Garinham north coast lane", radius = 0},
            {x = 14, y = 4, name = "Garinham mountain shoulder", radius = 0},
            {x = 15, y = 4, name = "Garinham shoulder east step", radius = 0},
            {x = 16, y = 5, name = "Garinham shoulder bend", radius = 0},
            {x = 16, y = 6, name = "Garinham east ridge", radius = 0},
            {x = 19, y = 6, name = "Garinham ridge entry", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 20, y = 7, name = "Garinham field east lane", radius = 0},
            {x = 20, y = 9, name = "Garinham east field", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 21, y = 10, name = "Garinham field road bend", radius = 0},
            {x = 21, y = 11, name = "Cave road north edge", radius = 0},
            {x = 23, y = 11, name = "Cave road west lane", radius = 0},
            {x = 23, y = 13, name = "Cave road south lane", radius = 1},
            {x = 28, y = 13, name = "Erdrick's Cave road", radius = 1},
            {x = 28, y = 20, name = "North trail marker", radius = 1},
            {x = 32, y = 19, name = "North ridge bend", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 35, y = 24, name = "Eastern mountain lane", radius = 0},
            {x = 35, y = 32, name = "East choke approach", radius = 0},
            {x = 38, y = 32, name = "Upper bridge lane", radius = 0},
            {x = 38, y = 34, name = "Bridge west bend", radius = 0, axis_order = {"horizontal", "vertical"}},
            {
                x = 38,
                y = 36,
                name = "Bridge lower west lane",
                radius = 0,
            },
            {
                x = 44,
                y = 38,
                name = "Bridge south bend",
                radius = 1,
                warning = "Bridge crossing. Monsters should become safer beyond this point.",
            },
            {x = 43, y = 43, name = "Tantegel Castle", radius = 0, final = true},
        },
    },
    tantegel_kol = {
        id = "tantegel_kol",
        title = "Tantegel Castle",
        aliases = {"kol to tantegel", "kol to castle", "tantegel from kol", "castle from kol", "return from kol"},
        target_object_ids = {"overworld_tantegel_castle"},
        destination_maps = {0x04, 0x05},
        staging = TANTEGEL_RETURN_STAGING,
        -- Route selection only: Hauksness should choose this staged return
        -- instead of the generic safety route's distant north-ridge waypoint.
        -- Staging still uses the real route distance and therefore begins on
        -- kol_return_staging rather than synthesizing a direct Kol shortcut.
        selection_anchors = {
            {x = 25, y = 89},
            {x = 29, y = 57},
        },
        waypoints = {
            {x = 104, y = 10, name = "Kol", radius = 1},
            {x = 96, y = 13, name = "Kol forest west edge", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 96, y = 21, name = "West of Kol north lane", radius = 1},
            {x = 98, y = 26, name = "Kol south road east detour", radius = 0, axis_order = {"vertical", "horizontal"}},
            {x = 98, y = 32, name = "Kol south road lower east lane", radius = 0},
            {x = 96, y = 32, name = "Kol south road", radius = 1},
            {x = 96, y = 35, name = "Kol south road east lane", radius = 0},
            {x = 93, y = 35, name = "Kol south road lower bend", radius = 0},
            {x = 93, y = 36, name = "Kol south road bend", radius = 0},
            {x = 92, y = 36, name = "Kol lower south lane", radius = 0},
            {x = 92, y = 37, name = "Kol bridge east lane", radius = 0},
            {x = 90, y = 37, name = "Kol southwest bridge", radius = 0},
            {x = 84, y = 26, name = "Kol southwest track", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 74, y = 18, name = "North Alefgard bridge road", radius = 1, axis_order = {"horizontal", "vertical"}},
            {
                x = 61,
                y = 18,
                name = "Northeast bridge",
                radius = 1,
                axis_order = {"horizontal", "vertical"},
                warning = "Northeast bridge crossing. Monsters should become safer beyond this point.",
            },
            {x = 61, y = 19, name = "Northeast bridge south lane", radius = 0},
            {x = 59, y = 19, name = "Northeast bridge lower west lane", radius = 0},
            {x = 58, y = 18, name = "Northeast bridge west bend", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 54, y = 15, name = "Northeast bridge west approach", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 45, y = 13, name = "North Alefgard east road", radius = 1, axis_order = {"vertical", "horizontal"}},
            {x = 35, y = 13, name = "North Alefgard west road", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 28, y = 13, name = "Erdrick's Cave road", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 28, y = 20, name = "North trail marker", radius = 1},
            {x = 32, y = 19, name = "North ridge bend", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 35, y = 24, name = "Eastern mountain lane", radius = 0},
            {x = 35, y = 32, name = "East choke approach", radius = 0},
            {x = 38, y = 32, name = "Upper bridge lane", radius = 0},
            {x = 38, y = 34, name = "Bridge west bend", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 38, y = 36, name = "Bridge lower west lane", radius = 0},
            {
                x = 44,
                y = 38,
                name = "Bridge south bend",
                radius = 1,
                warning = "Bridge crossing. Monsters should become safer beyond this point.",
            },
            {x = 43, y = 43, name = "Tantegel Castle", radius = 0, final = true},
        },
    },
}

local function copy_waypoint(point)
    local result = {}
    for key, value in pairs(point or {}) do
        result[key] = value
    end
    return result
end

local function copy_route_prefix(route, stop_x, stop_y)
    local result = {}
    for _, point in ipairs(route and route.waypoints or {}) do
        local copied = copy_waypoint(point)
        result[#result + 1] = copied
        if point.x == stop_x and point.y == stop_y then
            copied.final = true
            return result
        end
    end
    error(string.format(
        "route %s does not contain connector pin (%s,%s)",
        tostring(route and route.id or "-"),
        tostring(stop_x),
        tostring(stop_y)))
end

local function copy_route_with_kol_bypass(route, stop_x, stop_y)
    local result
    if stop_x ~= nil and stop_y ~= nil then
        result = copy_route_prefix(route, stop_x, stop_y)
    else
        result = {}
        for _, point in ipairs(route and route.waypoints or {}) do
            result[#result + 1] = copy_waypoint(point)
        end
    end
    local first = result[1]
    if not first or first.x ~= 104 or first.y ~= 10 then
        error(string.format(
            "route %s does not begin at Kol (104,10)",
            tostring(route and route.id or "-")))
    end
    first.x = 103
    first.name = "Kol west doorstep"
    return result
end

-- Internal hub leg: direct Kol travel still enters the town, but connected
-- destinations hand off one tile west of its entrance. The copied Kol route
-- also inherits the Brecconary west bypass, so neither intermediate town
-- interrupts a longer itinerary.
local kol_staging_waypoints = copy_route_prefix(ROUTES.kol, 104, 10)
local kol_staging_final = kol_staging_waypoints[#kol_staging_waypoints]
kol_staging_final.x = 103
kol_staging_final.name = "Kol west doorstep"
ROUTES.kol_staging = {
    id = "kol_staging",
    title = "Kol",
    destination_maps = {0x07},
    waypoints = kol_staging_waypoints,
}

-- Internal hub leg: connected Cantlin travel follows the established
-- Hauksness corridor but hands off from the west doorstep instead of entering
-- the ruins. Direct Hauksness travel retains the final eastward entry step.
ROUTES.hauksness_staging = {
    id = "hauksness_staging",
    title = "Hauksness",
    destination_maps = {0x03},
    staging = HAUKSNESS_HUB_STAGING,
    waypoints = copy_route_prefix(ROUTES.hauksness, 24, 89),
}

-- Internal hub leg: passing routes follow the live-validated Cantlin approach
-- only to its northwest turn. Direct Cantlin travel retains the eastward and
-- southward segments into town, and destination_maps preserves an accidental-
-- entry fallback for an active connected itinerary.
ROUTES.cantlin_staging = {
    id = "cantlin_staging",
    title = "Cantlin northwest turn",
    destination_maps = {0x0A},
    staging = CANTLIN_BYPASS_STAGING,
    waypoints = copy_route_prefix(ROUTES.cantlin_hauksness, 68, 91),
}

-- Internal return leg: reuse the live-validated Great Swamp return only through
-- Cantlin's northwest turn. Direct Cantlin travel still enters town.
ROUTES.cantlin_return_staging = {
    id = "cantlin_return_staging",
    title = "Cantlin northwest turn",
    destination_maps = {0x0A},
    waypoints = copy_route_prefix(ROUTES.cantlin_great_swamp, 68, 91),
}

-- Internal return leg: connected northern travel passes Hauksness from the
-- west doorstep instead of entering the ruins.
ROUTES.hauksness_return_staging = {
    id = "hauksness_return_staging",
    title = "Hauksness",
    destination_maps = {0x03},
    staging = CANTLIN_RETURN_STAGING,
    waypoints = copy_route_prefix(ROUTES.hauksness_cantlin, 24, 89),
}

-- Internal return leg: reuse the established Hauksness-to-Kol route, but stop
-- one tile west of Kol so the final Tantegel leg can leave without town entry.
local kol_return_staging_waypoints = copy_route_prefix(ROUTES.kol_hauksness, 104, 10)
local kol_return_staging_final = kol_return_staging_waypoints[#kol_return_staging_waypoints]
kol_return_staging_final.x = 103
kol_return_staging_final.name = "Kol west doorstep"
ROUTES.kol_return_staging = {
    id = "kol_return_staging",
    title = "Kol",
    destination_maps = {0x07},
    staging = HAUKSNESS_RETURN_STAGING,
    waypoints = kol_return_staging_waypoints,
}

-- Internal return leg: after the player crosses Swamp Cave from south to
-- north, reuse the validated cave-to-Kol route but stop one tile west of town.
local kol_swamp_cave_staging_waypoints = copy_route_prefix(
    ROUTES.kol_swamp_cave, 104, 10)
local kol_swamp_cave_staging_final =
    kol_swamp_cave_staging_waypoints[#kol_swamp_cave_staging_waypoints]
kol_swamp_cave_staging_final.x = 103
kol_swamp_cave_staging_final.name = "Kol west doorstep"
ROUTES.kol_swamp_cave_staging = {
    id = "kol_swamp_cave_staging",
    title = "Kol",
    -- After the manual south-to-north crossing, Travel refresh can leave the
    -- physical north entrance selected. Treat it as a read-only landmark so
    -- route guidance reports the staged destination instead of replacing it
    -- with a new route back to Swamp Cave.
    compatible_target_object_ids = {"overworld_swamp_cave"},
    destination_maps = {0x07},
    staging = KOL_SWAMP_CAVE_RETURN_STAGING,
    waypoints = kol_swamp_cave_staging_waypoints,
}

-- Direct south-island Kol travel, including Magic Temple and final-island
-- starts, differs from connected pass-through routes: after the manual cave
-- crossing it follows the canonical north-exit route all the way into town
-- instead of stopping outside.
ROUTES.kol_swamp_cave_south = {
    id = "kol_swamp_cave_south",
    title = "Kol",
    target_object_ids = {"overworld_kol"},
    compatible_target_object_ids = {
        "overworld_swamp_cave_south_entrance",
        "overworld_swamp_cave",
    },
    destination_maps = {0x07},
    staging = SOUTH_ISLAND_NORTH_EXIT_STAGING,
    selection_anchors = {
        {x = 104, y = 49, max_distance = 4},
        {x = 102, y = 72, max_distance = 4},
        {x = 108, y = 109, max_distance = 4},
        {x = 65, y = 49, max_distance = 4},
        {x = 48, y = 48, max_distance = 4},
    },
    waypoints = copy_route_prefix(ROUTES.kol_swamp_cave, 104, 10),
}

-- The north entrance is physically close to the south entrance but separated
-- by impassable overworld terrain. Reach the south entrance normally, cross
-- the cave manually, and complete only after emerging on the north side.
ROUTES.swamp_cave_north_swamp_cave_south = {
    id = "swamp_cave_north_swamp_cave_south",
    title = "Swamp Cave North Entrance",
    target_object_ids = {"overworld_swamp_cave"},
    compatible_target_object_ids = {
        "overworld_swamp_cave_south_entrance",
    },
    staging = SOUTH_ISLAND_NORTH_EXIT_STAGING,
    selection_anchors = {
        {x = 104, y = 49, max_distance = 4},
        {x = 102, y = 72, max_distance = 4},
        {x = 108, y = 109, max_distance = 4},
        {x = 65, y = 49, max_distance = 4},
        {x = 48, y = 48, max_distance = 4},
    },
    waypoints = {
        {
            x = 104,
            y = 44,
            name = "Swamp Cave North Entrance",
            radius = 0,
            final = true,
        },
    },
}

-- Internal eastern hub leg: reverse the validated Kol route only through the
-- shared bridge junction. Garinham, Erdrick's Cave, and Brecconary all contain
-- this exact pin, so connected travel can hand off without entering Tantegel.
ROUTES.tantegel_bridge_staging = {
    id = "tantegel_bridge_staging",
    title = "Tantegel bridge junction",
    staging = NORTHERN_CAVE_BRIDGE_STAGING,
    waypoints = copy_route_prefix(ROUTES.tantegel_kol, 44, 38),
}

-- Western origins need the same exterior bridge junction, but must first
-- return through Hauksness and Kol rather than taking the Northern Cave
-- shrine return used by tantegel_bridge_staging.
ROUTES.tantegel_bridge_western_staging = {
    id = "tantegel_bridge_western_staging",
    title = "Tantegel bridge junction",
    staging = {
        route_id = "kol_return_staging",
        max_start_distance = 13,
        require_route_corridor = true,
        continue_after_staging = true,
    },
    waypoints = copy_route_prefix(ROUTES.tantegel_kol, 44, 38),
}

-- Swamp-Cave-North requests use the same bridge-junction geometry, but first
-- return through the established cave-to-Kol corridor. Keeping this separate
-- from the Northern Cave variant isolates the two origin-specific staging
-- chains while preserving the shared exterior handoff at (44,38).
ROUTES.tantegel_bridge_swamp_cave_staging = {
    id = "tantegel_bridge_swamp_cave_staging",
    title = "Tantegel bridge junction",
    staging = SWAMP_CAVE_NORTH_BRIDGE_STAGING,
    waypoints = copy_route_prefix(ROUTES.tantegel_kol, 44, 38),
}

-- Kol-origin destination variants preserve the selected early landmark while
-- the hidden bridge leg returns across the established northern corridor.
-- Direct starts keep using the canonical routes and their normal town/cave
-- arrival behavior.
ROUTES.garinham_kol = {
    id = "garinham_kol",
    title = "Garinham",
    target_object_ids = {"overworld_garinham"},
    destination_maps = {0x09},
    staging = EARLY_DESTINATION_KOL_STAGING,
    selection_anchors = {
        {x = 104, y = 10, max_distance = 4},
        {x = 81, y = 1, max_distance = 4},
    },
    waypoints = copy_route_prefix(ROUTES.garinham, 1, 2),
}

ROUTES.erdrick_kol = {
    id = "erdrick_kol",
    title = "Erdrick's Cave",
    target_object_ids = {"overworld_erdrick_s_cave"},
    destination_maps = {0x1C, 0x1D},
    staging = EARLY_DESTINATION_KOL_STAGING,
    selection_anchors = {
        {x = 104, y = 10, max_distance = 4},
        {x = 81, y = 1, max_distance = 4},
    },
    waypoints = copy_route_prefix(ROUTES.erdrick, 28, 12),
}

ROUTES.brecconary_kol = {
    id = "brecconary_kol",
    title = "Brecconary",
    target_object_ids = {"overworld_brecconary"},
    destination_maps = {0x08},
    staging = EARLY_DESTINATION_KOL_STAGING,
    selection_anchors = {
        {x = 104, y = 10, max_distance = 4},
        {x = 81, y = 1, max_distance = 4},
    },
    waypoints = copy_route_prefix(ROUTES.brecconary, 48, 41),
}

-- Western-origin early destinations share the full validated return through
-- Cantlin, Hauksness, Kol, and the Tantegel bridge junction. Separate target
-- variants keep that staging chain scoped to the four western anchors.
local western_early_destination_anchors = {
    {x = 25, y = 89, max_distance = 4},
    {x = 29, y = 57, max_distance = 4},
    {x = 73, y = 102, max_distance = 4},
    {x = 89, y = 112, max_distance = 4},
}

ROUTES.brecconary_western_return = {
    id = "brecconary_western_return",
    title = "Brecconary",
    target_object_ids = {"overworld_brecconary"},
    destination_maps = {0x08},
    staging = WESTERN_EARLY_DESTINATION_STAGING,
    selection_anchors = western_early_destination_anchors,
    waypoints = copy_route_prefix(ROUTES.brecconary, 48, 41),
}

ROUTES.erdrick_western_return = {
    id = "erdrick_western_return",
    title = "Erdrick's Cave",
    target_object_ids = {"overworld_erdrick_s_cave"},
    destination_maps = {0x1C, 0x1D},
    staging = WESTERN_EARLY_DESTINATION_STAGING,
    selection_anchors = western_early_destination_anchors,
    waypoints = copy_route_prefix(ROUTES.erdrick, 28, 12),
}

ROUTES.garinham_western_return = {
    id = "garinham_western_return",
    title = "Garinham",
    target_object_ids = {"overworld_garinham"},
    destination_maps = {0x09},
    staging = WESTERN_EARLY_DESTINATION_STAGING,
    selection_anchors = western_early_destination_anchors,
    waypoints = copy_route_prefix(ROUTES.garinham, 1, 2),
}

-- Swamp-Cave-North destination variants preserve the selected early landmark
-- while the hidden return legs bypass Kol and stop at the bridge junction.
-- The radius deliberately excludes Swamp Cave's south entrance; broader
-- southern-island composition remains a separate validation slice.
ROUTES.garinham_swamp_cave_north = {
    id = "garinham_swamp_cave_north",
    title = "Garinham",
    target_object_ids = {"overworld_garinham"},
    destination_maps = {0x09},
    staging = SWAMP_CAVE_NORTH_EARLY_DESTINATION_STAGING,
    selection_anchors = {{x = 104, y = 44, max_distance = 4}},
    waypoints = copy_route_prefix(ROUTES.garinham, 1, 2),
}

ROUTES.erdrick_swamp_cave_north = {
    id = "erdrick_swamp_cave_north",
    title = "Erdrick's Cave",
    target_object_ids = {"overworld_erdrick_s_cave"},
    destination_maps = {0x1C, 0x1D},
    staging = SWAMP_CAVE_NORTH_EARLY_DESTINATION_STAGING,
    selection_anchors = {{x = 104, y = 44, max_distance = 4}},
    waypoints = copy_route_prefix(ROUTES.erdrick, 28, 12),
}

ROUTES.brecconary_swamp_cave_north = {
    id = "brecconary_swamp_cave_north",
    title = "Brecconary",
    target_object_ids = {"overworld_brecconary"},
    destination_maps = {0x08},
    staging = SWAMP_CAVE_NORTH_EARLY_DESTINATION_STAGING,
    selection_anchors = {{x = 104, y = 44, max_distance = 4}},
    waypoints = copy_route_prefix(ROUTES.brecconary, 48, 41),
}

-- South-island early destinations first reuse the proven Rimuldar-to-cave
-- return when needed, wait for automatic Swamp Cave entry, preserve the
-- selected destination during the manual crossing, then reuse the existing
-- north-exit, Kol-bypass, bridge-junction, and final legs.
ROUTES.brecconary_swamp_cave_south = {
    id = "brecconary_swamp_cave_south",
    title = "Brecconary",
    target_object_ids = {"overworld_brecconary"},
    destination_maps = {0x08},
    staging = SWAMP_CAVE_SOUTH_EARLY_DESTINATION_STAGING,
    selection_anchors = {
        {x = 104, y = 49, max_distance = 4},
        {x = 102, y = 72, max_distance = 4},
        {x = 108, y = 109, max_distance = 4},
        {x = 65, y = 49, max_distance = 4},
        {x = 48, y = 48, max_distance = 4},
    },
    waypoints = copy_route_prefix(ROUTES.brecconary, 48, 41),
}

ROUTES.erdrick_swamp_cave_south = {
    id = "erdrick_swamp_cave_south",
    title = "Erdrick's Cave",
    target_object_ids = {"overworld_erdrick_s_cave"},
    destination_maps = {0x1C, 0x1D},
    staging = SWAMP_CAVE_SOUTH_EARLY_DESTINATION_STAGING,
    selection_anchors = {
        {x = 104, y = 49, max_distance = 4},
        {x = 102, y = 72, max_distance = 4},
        {x = 108, y = 109, max_distance = 4},
        {x = 65, y = 49, max_distance = 4},
        {x = 48, y = 48, max_distance = 4},
    },
    waypoints = copy_route_prefix(ROUTES.erdrick, 28, 12),
}

ROUTES.garinham_swamp_cave_south = {
    id = "garinham_swamp_cave_south",
    title = "Garinham",
    target_object_ids = {"overworld_garinham"},
    destination_maps = {0x09},
    staging = SWAMP_CAVE_SOUTH_EARLY_DESTINATION_STAGING,
    selection_anchors = {
        {x = 104, y = 49, max_distance = 4},
        {x = 102, y = 72, max_distance = 4},
        {x = 108, y = 109, max_distance = 4},
        {x = 65, y = 49, max_distance = 4},
        {x = 48, y = 48, max_distance = 4},
    },
    waypoints = copy_route_prefix(ROUTES.garinham, 1, 2),
}

-- Internal southern hub legs: connected routes reuse both live-validated
-- Rimuldar approaches only through the east doorstep. Direct Rimuldar travel
-- retains the final westward step that enters town.
ROUTES.rimuldar_staging = {
    id = "rimuldar_staging",
    title = "Rimuldar",
    compatible_target_object_ids = {
        "overworld_swamp_cave_south_entrance",
    },
    destination_maps = {0x0B},
    staging = RIMULDAR_STAGING,
    waypoints = copy_route_prefix(ROUTES.rimuldar, 103, 72),
}

ROUTES.rimuldar_magic_temple_staging = {
    id = "rimuldar_magic_temple_staging",
    title = "Rimuldar",
    destination_maps = {0x0B},
    waypoints = copy_route_prefix(ROUTES.rimuldar_magic_temple, 103, 72),
}

-- Internal southern-return variant: Magic Temple starts must first reverse the
-- live-validated temple route to Rimuldar's east doorstep. From there this
-- copy follows the established Rimuldar-to-Swamp-Cave leg, allowing the
-- existing nested return chain to continue through the cave, around Kol, and
-- on to Tantegel without entering town.
ROUTES.swamp_cave_south_magic_temple = {
    id = "swamp_cave_south_magic_temple",
    title = "Swamp Cave South Entrance",
    target_object_ids = {"overworld_swamp_cave_south_entrance"},
    staged_handoff_requires_destination_map = true,
    staged_transition_message =
        "Swamp Cave opens automatically when you step onto this tile. " ..
        "If already here, step off and back on, then cross to the north exit.",
    destination_maps = {0x15},
    staging = {
        route_id = "rimuldar_magic_temple_staging",
        max_start_distance = 13,
        require_route_corridor = true,
        continue_after_staging = true,
    },
    selection_anchors = {{x = 108, y = 109, max_distance = 4}},
    waypoints = copy_route_prefix(ROUTES.swamp_cave_south, 104, 49),
}

-- Internal return leg: reuse the live-validated Northern-Cave-to-Kol route,
-- but stop one tile west of Kol so the final Tantegel leg can leave without
-- entering town.
local kol_rain_shrine_staging_waypoints = copy_route_prefix(
    ROUTES.kol_rain_shrine, 104, 10)
local kol_rain_shrine_staging_final =
    kol_rain_shrine_staging_waypoints[#kol_rain_shrine_staging_waypoints]
kol_rain_shrine_staging_final.x = 103
kol_rain_shrine_staging_final.name = "Kol west doorstep"
ROUTES.kol_rain_shrine_staging = {
    id = "kol_rain_shrine_staging",
    title = "Kol",
    destination_maps = {0x07},
    waypoints = kol_rain_shrine_staging_waypoints,
}

-- Destination-selection variant: only a Northern Cave-origin Tantegel request
-- chooses this route. Its staging chain follows the established shrine return,
-- bypasses Kol, and hands off to the established castle leg.
ROUTES.tantegel_northern_cave = {
    id = "tantegel_northern_cave",
    title = "Tantegel Castle",
    target_object_ids = {"overworld_tantegel_castle"},
    destination_maps = {0x04, 0x05},
    staging = NORTHERN_CAVE_TANTEGEL_STAGING,
    selection_anchors = {{x = 81, y = 1, max_distance = 4}},
    waypoints = copy_route_prefix(ROUTES.tantegel_kol, 43, 43),
}

-- Destination-selection variant: a Tantegel request at Swamp Cave's north
-- exit follows the established non-entry Kol return before joining the
-- established castle leg.
ROUTES.tantegel_swamp_cave_north = {
    id = "tantegel_swamp_cave_north",
    title = "Tantegel Castle",
    target_object_ids = {"overworld_tantegel_castle"},
    destination_maps = {0x04, 0x05},
    staging = SWAMP_CAVE_TANTEGEL_STAGING,
    selection_anchors = {{x = 104, y = 44, max_distance = 4}},
    waypoints = copy_route_prefix(ROUTES.tantegel_kol, 43, 43),
}

-- Destination-selection variant: a Rimuldar- or Swamp-Cave-south-origin
-- Tantegel request chooses this route. Its staging chain crosses Swamp Cave,
-- follows the non-entry Kol return, and finally hands off to the established
-- castle leg.
ROUTES.tantegel_rimuldar = {
    id = "tantegel_rimuldar",
    title = "Tantegel Castle",
    target_object_ids = {"overworld_tantegel_castle"},
    destination_maps = {0x04, 0x05},
    staging = SWAMP_CAVE_TANTEGEL_STAGING,
    selection_anchors = {
        {x = 102, y = 72, max_distance = 4},
        {x = 104, y = 49, max_distance = 4},
    },
    waypoints = copy_route_prefix(ROUTES.tantegel_kol, 43, 43),
}

-- Destination-selection variant: a Charlock- or Rainbow-Bridge-origin
-- Tantegel request first reverses the matching live-validated final-island
-- route. The existing nested staging then crosses Swamp Cave, bypasses Kol,
-- and joins the established castle leg.
ROUTES.tantegel_charlock = {
    id = "tantegel_charlock",
    title = "Tantegel Castle",
    target_object_ids = {"overworld_tantegel_castle"},
    destination_maps = {0x04, 0x05},
    staging = SWAMP_CAVE_TANTEGEL_STAGING,
    selection_anchors = {
        {x = 48, y = 48, max_distance = 4},
        {x = 65, y = 49, max_distance = 4},
    },
    waypoints = copy_route_prefix(ROUTES.tantegel_kol, 43, 43),
}

-- Destination-selection variant: a Magic-Temple-origin Tantegel request first
-- reverses the validated temple route to Rimuldar. Nested staging then reaches
-- Swamp Cave, bypasses Kol, and joins the established castle leg.
ROUTES.tantegel_magic_temple = {
    id = "tantegel_magic_temple",
    title = "Tantegel Castle",
    target_object_ids = {"overworld_tantegel_castle"},
    destination_maps = {0x04, 0x05},
    staging = SWAMP_CAVE_TANTEGEL_STAGING,
    selection_anchors = {{x = 108, y = 109, max_distance = 4}},
    waypoints = copy_route_prefix(ROUTES.tantegel_kol, 43, 43),
}

-- Internal staging leg: reuse the live-validated Hauksness corridor from Kol
-- only through the Mountain Cave junction. Keeping this derived avoids a
-- second manually maintained copy of more than sixty waypoint turns.
ROUTES.mountain_cave_connector = {
    id = "mountain_cave_connector",
    title = "Western desert east road",
    staging = MOUNTAIN_CAVE_CONNECTOR_STAGING,
    waypoints = copy_route_prefix(ROUTES.hauksness, 18, 64),
}

-- Swamp-Cave-North variants reuse the proven cave return and hand off at
-- Kol's west doorstep. Direct destination routes retain their town-entry
-- behavior, while these connected variants begin at the exterior tile.
ROUTES.northern_cave_swamp_cave_north = {
    id = "northern_cave_swamp_cave_north",
    title = "Northern Cave",
    target_object_ids = {"overworld_northern_cave"},
    destination_maps = {0x0D},
    staging = SWAMP_CAVE_NORTH_KOL_DESTINATION_STAGING,
    selection_anchors = {{x = 104, y = 44, max_distance = 4}},
    waypoints = copy_route_with_kol_bypass(ROUTES.northern_cave),
}

ROUTES.hauksness_swamp_cave_north = {
    id = "hauksness_swamp_cave_north",
    title = "Hauksness",
    target_object_ids = {"overworld_hauksness"},
    destination_maps = {0x03},
    staging = SWAMP_CAVE_NORTH_KOL_DESTINATION_STAGING,
    selection_anchors = {{x = 104, y = 44, max_distance = 4}},
    waypoints = copy_route_with_kol_bypass(ROUTES.hauksness),
}

-- South- and final-island northwestern variants first reuse the proven local
-- return to Swamp Cave south, wait for automatic cave entry, then resume at
-- the north exit and hand off outside Kol to these destination legs.
ROUTES.northern_cave_swamp_cave_south = {
    id = "northern_cave_swamp_cave_south",
    title = "Northern Cave",
    target_object_ids = {"overworld_northern_cave"},
    destination_maps = {0x0D},
    staging = SWAMP_CAVE_NORTH_KOL_DESTINATION_STAGING,
    selection_anchors = {
        {x = 104, y = 49, max_distance = 4},
        {x = 102, y = 72, max_distance = 4},
        {x = 108, y = 109, max_distance = 4},
        {x = 65, y = 49, max_distance = 4},
        {x = 48, y = 48, max_distance = 4},
    },
    waypoints = copy_route_with_kol_bypass(ROUTES.northern_cave),
}

ROUTES.hauksness_swamp_cave_south = {
    id = "hauksness_swamp_cave_south",
    title = "Hauksness",
    target_object_ids = {"overworld_hauksness"},
    destination_maps = {0x03},
    staging = SWAMP_CAVE_NORTH_KOL_DESTINATION_STAGING,
    selection_anchors = {
        {x = 104, y = 49, max_distance = 4},
        {x = 102, y = 72, max_distance = 4},
        {x = 108, y = 109, max_distance = 4},
        {x = 65, y = 49, max_distance = 4},
        {x = 48, y = 48, max_distance = 4},
    },
    waypoints = copy_route_with_kol_bypass(ROUTES.hauksness),
}

ROUTES.mountain_cave_swamp_cave_north_connector = {
    id = "mountain_cave_swamp_cave_north_connector",
    title = "Western desert east road",
    staging = SWAMP_CAVE_NORTH_WESTERN_CONNECTOR_STAGING,
    waypoints = copy_route_with_kol_bypass(ROUTES.mountain_cave_connector),
}

ROUTES.mountain_cave_swamp_cave_north = {
    id = "mountain_cave_swamp_cave_north",
    title = "Mountain Cave",
    target_object_ids = {"overworld_mountain_cave"},
    destination_maps = {0x16, 0x17},
    staging = SWAMP_CAVE_NORTH_MOUNTAIN_STAGING,
    selection_anchors = {{x = 104, y = 44, max_distance = 4}},
    waypoints = copy_route_prefix(ROUTES.mountain_cave, 29, 57),
}

ROUTES.mountain_cave_swamp_cave_south = {
    id = "mountain_cave_swamp_cave_south",
    title = "Mountain Cave",
    target_object_ids = {"overworld_mountain_cave"},
    destination_maps = {0x16, 0x17},
    -- Reuse the validated Kol-to-western-desert connector after the nested
    -- south-to-north cave crossing completes.
    staging = SWAMP_CAVE_NORTH_MOUNTAIN_STAGING,
    selection_anchors = {
        {x = 104, y = 49, max_distance = 4},
        {x = 102, y = 72, max_distance = 4},
        {x = 108, y = 109, max_distance = 4},
        {x = 65, y = 49, max_distance = 4},
        {x = 48, y = 48, max_distance = 4},
    },
    waypoints = copy_route_prefix(ROUTES.mountain_cave, 29, 57),
}

-- Internal hub leg: connected southern travel follows the existing Kol-to-
-- Hauksness corridor, but stops at the west doorstep instead of entering the
-- ruins. The copied route also keeps Kol's west-doorstep bypass.
ROUTES.hauksness_swamp_cave_north_staging = {
    id = "hauksness_swamp_cave_north_staging",
    title = "Hauksness",
    destination_maps = {0x03},
    staging = SWAMP_CAVE_NORTH_HAUKSNESS_HUB_STAGING,
    waypoints = copy_route_with_kol_bypass(ROUTES.hauksness, 24, 89),
}

-- Destination-selection variant: Swamp Cave north reaches Cantlin through
-- the proven Kol and Hauksness corridors without entering either landmark.
ROUTES.cantlin_swamp_cave_north = {
    id = "cantlin_swamp_cave_north",
    title = "Cantlin",
    target_object_ids = {"overworld_cantlin"},
    destination_maps = {0x0A},
    staging = SWAMP_CAVE_NORTH_CANTLIN_STAGING,
    selection_anchors = {{x = 104, y = 44, max_distance = 4}},
    waypoints = copy_route_prefix(ROUTES.cantlin_hauksness, 73, 102),
}

-- South- and final-island Cantlin travel first reuses the local cave return,
-- then nests through the manual crossing and the existing non-entry Kol and
-- Hauksness handoffs.
ROUTES.cantlin_swamp_cave_south = {
    id = "cantlin_swamp_cave_south",
    title = "Cantlin",
    target_object_ids = {"overworld_cantlin"},
    destination_maps = {0x0A},
    staging = SWAMP_CAVE_NORTH_CANTLIN_STAGING,
    selection_anchors = {
        {x = 104, y = 49, max_distance = 4},
        {x = 102, y = 72, max_distance = 4},
        {x = 108, y = 109, max_distance = 4},
        {x = 65, y = 49, max_distance = 4},
        {x = 48, y = 48, max_distance = 4},
    },
    waypoints = copy_route_prefix(ROUTES.cantlin_hauksness, 73, 102),
}

-- Internal hub leg: Great Swamp travel shares the Cantlin route only to its
-- northwest turn, preserving the existing town bypass before the final leg.
ROUTES.cantlin_swamp_cave_north_staging = {
    id = "cantlin_swamp_cave_north_staging",
    title = "Cantlin northwest turn",
    destination_maps = {0x0A},
    staging = SWAMP_CAVE_NORTH_CANTLIN_BYPASS_STAGING,
    waypoints = copy_route_prefix(ROUTES.cantlin_hauksness, 68, 91),
}

-- Destination-selection variant: Swamp Cave north reaches the eastern Great
-- Swamp search pin through the same exterior Kol, Hauksness, and Cantlin
-- handoffs, then reuses the live-validated Cantlin-to-swamp route.
ROUTES.great_swamp_swamp_cave_north = {
    id = "great_swamp_swamp_cave_north",
    title = "Eastern Great Swamp Search Area",
    target_object_ids = {
        "overworld_eastern_great_swamp_search_area",
    },
    staging = SWAMP_CAVE_NORTH_GREAT_SWAMP_STAGING,
    selection_anchors = {{x = 104, y = 44, max_distance = 4}},
    waypoints = copy_route_prefix(ROUTES.great_swamp_cantlin, 89, 112),
}

-- South- and final-island Great Swamp travel first returns to Swamp Cave,
-- then follows the shared cave, Kol, Hauksness, and Cantlin-bypass chain.
ROUTES.great_swamp_swamp_cave_south = {
    id = "great_swamp_swamp_cave_south",
    title = "Eastern Great Swamp Search Area",
    target_object_ids = {
        "overworld_eastern_great_swamp_search_area",
    },
    staging = SWAMP_CAVE_NORTH_GREAT_SWAMP_STAGING,
    selection_anchors = {
        {x = 104, y = 49, max_distance = 4},
        {x = 102, y = 72, max_distance = 4},
        {x = 108, y = 109, max_distance = 4},
        {x = 65, y = 49, max_distance = 4},
        {x = 48, y = 48, max_distance = 4},
    },
    waypoints = copy_route_prefix(ROUTES.great_swamp_cantlin, 89, 112),
}

-- Northwestern destination variants repair the remaining asymmetric return
-- matrix. Every affected origin first reaches Kol through either the proven
-- Rain Shrine return or the nested Mountain/Cantlin/Hauksness return. The
-- destination legs below reuse existing geometry and retain town bypasses for
-- intermediate handoffs.
ROUTES.kol_northwestern_return = {
    id = "kol_northwestern_return",
    title = "Kol",
    target_object_ids = {"overworld_kol"},
    destination_maps = {0x07},
    staging = NORTHWESTERN_KOL_RETURN_STAGING,
    selection_anchors = {
        {x = 29, y = 57, max_distance = 4},
        {x = 73, y = 102, max_distance = 4},
        {x = 89, y = 112, max_distance = 4},
    },
    waypoints = {
        {x = 104, y = 10, name = "Kol", radius = 0, final = true},
    },
}

ROUTES.northern_cave_northwestern_return = {
    id = "northern_cave_northwestern_return",
    title = "Northern Cave",
    target_object_ids = {"overworld_northern_cave"},
    destination_maps = {0x0D},
    staging = NORTHWESTERN_KOL_RETURN_STAGING,
    selection_anchors = {
        {x = 29, y = 57, max_distance = 4},
        {x = 25, y = 89, max_distance = 4},
        {x = 73, y = 102, max_distance = 4},
        {x = 89, y = 112, max_distance = 4},
    },
    waypoints = copy_route_with_kol_bypass(ROUTES.northern_cave),
}

ROUTES.mountain_cave_northwestern_connector = {
    id = "mountain_cave_northwestern_connector",
    title = "Western desert east road",
    staging = NORTHWESTERN_KOL_RETURN_STAGING,
    waypoints = copy_route_with_kol_bypass(ROUTES.mountain_cave_connector),
}

ROUTES.mountain_cave_northwestern_return = {
    id = "mountain_cave_northwestern_return",
    title = "Mountain Cave",
    target_object_ids = {"overworld_mountain_cave"},
    destination_maps = {0x16, 0x17},
    staging = NORTHWESTERN_MOUNTAIN_STAGING,
    selection_anchors = {
        {x = 81, y = 1, max_distance = 4},
        {x = 25, y = 89, max_distance = 4},
        {x = 73, y = 102, max_distance = 4},
        {x = 89, y = 112, max_distance = 4},
    },
    waypoints = copy_route_prefix(ROUTES.mountain_cave, 29, 57),
}

ROUTES.hauksness_northwestern_return = {
    id = "hauksness_northwestern_return",
    title = "Hauksness",
    target_object_ids = {"overworld_hauksness"},
    destination_maps = {0x03},
    staging = NORTHWESTERN_KOL_RETURN_STAGING,
    selection_anchors = {
        {x = 81, y = 1, max_distance = 4},
        {x = 29, y = 57, max_distance = 4},
        {x = 89, y = 112, max_distance = 4},
    },
    waypoints = copy_route_with_kol_bypass(ROUTES.hauksness),
}

ROUTES.hauksness_northwestern_staging = {
    id = "hauksness_northwestern_staging",
    title = "Hauksness",
    destination_maps = {0x03},
    staging = NORTHWESTERN_KOL_RETURN_STAGING,
    waypoints = copy_route_with_kol_bypass(ROUTES.hauksness, 24, 89),
}

ROUTES.cantlin_northwestern_return = {
    id = "cantlin_northwestern_return",
    title = "Cantlin",
    target_object_ids = {"overworld_cantlin"},
    destination_maps = {0x0A},
    staging = NORTHWESTERN_CANTLIN_STAGING,
    selection_anchors = {
        {x = 81, y = 1, max_distance = 4},
        {x = 29, y = 57, max_distance = 4},
    },
    waypoints = copy_route_prefix(ROUTES.cantlin_hauksness, 73, 102),
}

ROUTES.cantlin_northwestern_staging = {
    id = "cantlin_northwestern_staging",
    title = "Cantlin northwest turn",
    destination_maps = {0x0A},
    staging = NORTHWESTERN_CANTLIN_BYPASS_STAGING,
    waypoints = copy_route_prefix(ROUTES.cantlin_hauksness, 68, 91),
}

ROUTES.great_swamp_northwestern_return = {
    id = "great_swamp_northwestern_return",
    title = "Eastern Great Swamp Search Area",
    target_object_ids = {
        "overworld_eastern_great_swamp_search_area",
    },
    staging = NORTHWESTERN_GREAT_SWAMP_STAGING,
    selection_anchors = {
        {x = 81, y = 1, max_distance = 4},
        {x = 29, y = 57, max_distance = 4},
    },
    waypoints = copy_route_prefix(ROUTES.great_swamp_cantlin, 89, 112),
}

-- Internal cave-entry leg: when the hero is already standing on the automatic
-- north entrance tile, first step to the safe doorstep. The player then steps
-- south to retrigger entry and crosses the cave manually.
ROUTES.swamp_cave_north_entry_staging = {
    id = "swamp_cave_north_entry_staging",
    title = "Swamp Cave north re-entry stand",
    destination_maps = {0x15},
    staged_handoff_requires_destination_map = true,
    staged_transition_message =
        "Step south to re-enter Swamp Cave, then cross to the south exit.",
    waypoints = {
        {
            x = 104,
            y = 43,
            name = "Swamp Cave north re-entry stand",
            radius = 0,
            final = true,
        },
    },
}

-- Destination-selection variant: entering from the north pauses guidance
-- inside Swamp Cave, then completes only after the player emerges on the
-- southern World Map entrance. It deliberately has no destination map because
-- map 0x15 is the traversal, not the requested exterior arrival.
ROUTES.swamp_cave_south_swamp_cave_north = {
    id = "swamp_cave_south_swamp_cave_north",
    title = "Swamp Cave South Entrance",
    target_object_ids = {"overworld_swamp_cave_south_entrance"},
    staging = SWAMP_CAVE_NORTH_TO_SOUTH_STAGING,
    selection_anchors = {{x = 104, y = 44, max_distance = 1}},
    waypoints = {
        {
            x = 104,
            y = 49,
            name = "Swamp Cave South Entrance",
            radius = 0,
            final = true,
        },
    },
}

-- Internal eastern return: Garinham already has a live-validated route toward
-- Tantegel. Stop that route at the shared bridge junction so longer southern
-- itineraries can turn onto the established Kol corridor without entering a
-- town or inventing new waypoint geometry.
ROUTES.tantegel_garinham_staging = {
    id = "tantegel_garinham_staging",
    title = "Tantegel bridge junction",
    waypoints = copy_route_prefix(ROUTES.tantegel, 44, 38),
}

-- Continue from the shared bridge junction to Kol's west doorstep. This is a
-- separate wrapper so only Garinham-origin southern travel gains the eastern
-- staging leg; existing Kol staging behavior remains unchanged elsewhere.
ROUTES.kol_garinham_staging = {
    id = "kol_garinham_staging",
    title = "Kol",
    destination_maps = {0x07},
    staging = GARINHAM_KOL_STAGING,
    waypoints = copy_route_prefix(ROUTES.kol_staging, 103, 10),
}

-- Reach Swamp Cave north from Garinham through the proven bridge and Kol
-- chain. Automatic cave entry must occur before the next staged leg becomes
-- active, keeping auto-walk from injecting movement inside map 0x15.
ROUTES.swamp_cave_garinham_staging = {
    id = "swamp_cave_garinham_staging",
    title = "Swamp Cave",
    target_object_ids = {"overworld_swamp_cave"},
    destination_maps = {0x15},
    staged_handoff_requires_destination_map = true,
    staged_transition_message =
        "Enter Swamp Cave, then cross manually to the south exit.",
    staging = GARINHAM_SWAMP_CAVE_STAGING,
    selection_anchors = {{x = 1, y = 2, max_distance = 4}},
    waypoints = copy_route_prefix(ROUTES.swamp_cave, 104, 44),
}

-- Northern Cave starts reverse the proven rain-shrine corridor to Kol before
-- taking the established north-cave approach. The automatic cave transition
-- remains the handoff gate so connected southern routes never inject movement
-- inside map 0x15.
ROUTES.swamp_cave_northern_return_staging = {
    id = "swamp_cave_northern_return_staging",
    title = "Swamp Cave",
    destination_maps = {0x15},
    staged_handoff_requires_destination_map = true,
    staged_transition_message =
        "Enter Swamp Cave, then cross manually to the south exit.",
    staging = {
        route_id = "kol_rain_shrine_staging",
        max_start_distance = 13,
        require_route_corridor = true,
        continue_after_staging = true,
    },
    selection_anchors = {{x = 81, y = 1, max_distance = 4}},
    waypoints = copy_route_prefix(ROUTES.swamp_cave, 104, 44),
}

-- Western starts reuse the already validated return chain through Hauksness
-- and Kol before joining the same cave approach. Nested staging preserves the
-- Mountain Cave, Cantlin, and Great Swamp local returns without new geometry.
ROUTES.swamp_cave_western_return_staging = {
    id = "swamp_cave_western_return_staging",
    title = "Swamp Cave",
    destination_maps = {0x15},
    staged_handoff_requires_destination_map = true,
    staged_transition_message =
        "Enter Swamp Cave, then cross manually to the south exit.",
    staging = {
        route_id = "kol_return_staging",
        max_start_distance = 13,
        require_route_corridor = true,
        continue_after_staging = true,
    },
    selection_anchors = {
        {x = 25, y = 89, max_distance = 4},
        {x = 29, y = 57, max_distance = 4},
        {x = 73, y = 102, max_distance = 4},
        {x = 89, y = 112, max_distance = 4},
    },
    waypoints = copy_route_prefix(ROUTES.swamp_cave, 104, 44),
}

-- Mainland destination-selection variant: reach Swamp Cave north through the
-- origin's established corridor, cross manually, and resume at the south
-- entrance. Rainbow Bridge and Charlock staging reuse this same return.
ROUTES.swamp_cave_south_mainland = {
    id = "swamp_cave_south_mainland",
    title = "Swamp Cave South Entrance",
    target_object_ids = {"overworld_swamp_cave_south_entrance"},
    staging = MAINLAND_SWAMP_CAVE_SOUTH_STAGING,
    selection_anchors = {
        {x = 43, y = 43, max_distance = 4},
        {x = 48, y = 41, max_distance = 4},
        {x = 28, y = 12, max_distance = 4},
        {x = 1, y = 2, max_distance = 4},
        {x = 104, y = 10, max_distance = 4},
        {x = 81, y = 1, max_distance = 4},
        {x = 25, y = 89, max_distance = 4},
        {x = 29, y = 57, max_distance = 4},
        {x = 73, y = 102, max_distance = 4},
        {x = 89, y = 112, max_distance = 4},
    },
    waypoints = copy_route_prefix(
        ROUTES.swamp_cave_south_swamp_cave_north, 104, 49),
}

-- Destination-selection variant: Rimuldar travel from the north cave exit
-- reuses the proven re-entry pause, waits through the manual cave crossing,
-- then resumes the existing south-entrance-to-Rimuldar corridor unchanged.
ROUTES.rimuldar_swamp_cave_north = {
    id = "rimuldar_swamp_cave_north",
    title = "Rimuldar",
    target_object_ids = {"overworld_rimuldar"},
    compatible_target_object_ids = {
        "overworld_swamp_cave_south_entrance",
    },
    destination_maps = {0x0B},
    staging = SWAMP_CAVE_NORTH_TO_SOUTH_STAGING,
    selection_anchors = {{x = 104, y = 44, max_distance = 1}},
    waypoints = copy_route_prefix(ROUTES.rimuldar, 102, 72),
}

-- Internal hub leg: the north cave exit uses the manual cave-crossing pause,
-- then follows the live-validated Rimuldar corridor only to the east doorstep.
-- Direct Rimuldar travel retains its final town-entry step.
ROUTES.rimuldar_swamp_cave_north_staging = {
    id = "rimuldar_swamp_cave_north_staging",
    title = "Rimuldar",
    -- After the cave transition, Travel refresh can leave the physical south
    -- entrance selected. Keep that object bound to the active final itinerary
    -- so pressing route guidance reports status instead of replacing it.
    compatible_target_object_ids = {
        "overworld_swamp_cave_south_entrance",
    },
    destination_maps = {0x0B},
    staging = SWAMP_CAVE_NORTH_TO_SOUTH_STAGING,
    waypoints = copy_route_prefix(ROUTES.rimuldar, 103, 72),
}

-- Destination-selection variant: Swamp Cave north reaches Magic Temple by
-- crossing the cave manually, bypassing Rimuldar at its east doorstep, and
-- reusing the established Rimuldar-to-temple corridor unchanged.
ROUTES.magic_temple_swamp_cave_north = {
    id = "magic_temple_swamp_cave_north",
    title = "Magic Temple",
    target_object_ids = {"overworld_southern_cave"},
    destination_maps = {0x0E},
    staging = SWAMP_CAVE_NORTH_MAGIC_TEMPLE_STAGING,
    selection_anchors = {{x = 104, y = 44, max_distance = 1}},
    waypoints = copy_route_prefix(ROUTES.magic_temple, 108, 109),
}

-- Keep lookup deterministic, especially when several routes share a Travel target.
local ROUTE_IDS = {
    "brecconary",
    "brecconary_kol",
    "brecconary_western_return",
    "brecconary_swamp_cave_north",
    "brecconary_swamp_cave_south",
    "garinham",
    "garinham_kol",
    "garinham_western_return",
    "garinham_swamp_cave_north",
    "garinham_swamp_cave_south",
    "kol",
    "northern_cave",
    "northern_cave_swamp_cave_north",
    "northern_cave_swamp_cave_south",
    "northern_cave_northwestern_return",
    "kol_rain_shrine",
    "kol_swamp_cave",
    "kol_swamp_cave_south",
    "kol_hauksness",
    "kol_northwestern_return",
    "swamp_cave",
    "swamp_cave_bridge",
    "swamp_cave_north_swamp_cave_south",
    "rimuldar",
    "rimuldar_swamp_cave_north",
    "magic_temple",
    "magic_temple_swamp_cave_north",
    "rimuldar_magic_temple",
    "swamp_cave_south",
    "swamp_cave_south_mainland",
    "swamp_cave_south_swamp_cave_north",
    "swamp_cave_south_recovery",
    "rainbow_bridge",
    "rainbow_bridge_return",
    "charlock_castle",
    "charlock_return",
    "mountain_cave",
    "mountain_cave_swamp_cave_north",
    "mountain_cave_swamp_cave_south",
    "mountain_cave_return",
    "mountain_cave_northwestern_return",
    "hauksness",
    "hauksness_swamp_cave_north",
    "hauksness_swamp_cave_south",
    "hauksness_cantlin",
    "hauksness_northwestern_return",
    "cantlin_hauksness",
    "cantlin_swamp_cave_north",
    "cantlin_swamp_cave_south",
    "cantlin_northwestern_return",
    "great_swamp_cantlin",
    "great_swamp_swamp_cave_north",
    "great_swamp_swamp_cave_south",
    "great_swamp_northwestern_return",
    "cantlin_great_swamp",
    "erdrick",
    "erdrick_kol",
    "erdrick_western_return",
    "erdrick_swamp_cave_north",
    "erdrick_swamp_cave_south",
    "tantegel",
    "tantegel_kol",
    "tantegel_northern_cave",
    "tantegel_swamp_cave_north",
    "tantegel_rimuldar",
    "tantegel_charlock",
    "tantegel_magic_temple",
}

local ROUTE_ALTERNATES = {
    safety = {"brecconary", "tantegel"},
    brecconary = {
        "brecconary",
        "brecconary_kol",
        "brecconary_western_return",
        "brecconary_swamp_cave_north",
        "brecconary_swamp_cave_south",
    },
    garinham = {
        "garinham",
        "garinham_kol",
        "garinham_western_return",
        "garinham_swamp_cave_north",
        "garinham_swamp_cave_south",
    },
    erdrick = {
        "erdrick",
        "erdrick_kol",
        "erdrick_western_return",
        "erdrick_swamp_cave_north",
        "erdrick_swamp_cave_south",
    },
    kol = {
        "kol",
        "kol_rain_shrine",
        "kol_swamp_cave",
        "kol_swamp_cave_south",
        "kol_hauksness",
        "kol_northwestern_return",
    },
    northern_cave = {
        "northern_cave",
        "northern_cave_swamp_cave_north",
        "northern_cave_swamp_cave_south",
        "northern_cave_northwestern_return",
    },
    kol_rain_shrine = {"kol", "kol_rain_shrine", "kol_swamp_cave", "kol_hauksness"},
    kol_swamp_cave = {
        "kol_swamp_cave",
        "kol_swamp_cave_south",
        "kol",
        "kol_rain_shrine",
        "kol_hauksness",
    },
    kol_hauksness = {"kol_hauksness", "kol", "kol_rain_shrine", "kol_swamp_cave"},
    swamp_cave = {
        "swamp_cave_bridge",
        "swamp_cave",
        "swamp_cave_garinham_staging",
        "swamp_cave_northern_return_staging",
        "swamp_cave_western_return_staging",
        "swamp_cave_north_swamp_cave_south",
    },
    swamp_cave_bridge = {
        "swamp_cave_bridge",
        "swamp_cave",
        "swamp_cave_north_swamp_cave_south",
    },
    swamp_cave_south = {
        "swamp_cave_south",
        "swamp_cave_south_mainland",
        "swamp_cave_south_swamp_cave_north",
        "swamp_cave_south_recovery",
        "rainbow_bridge_return",
        "charlock_return",
        "swamp_cave_south_magic_temple",
    },
    swamp_cave_south_recovery = {
        "swamp_cave_south",
        "swamp_cave_south_recovery",
        "rainbow_bridge_return",
        "charlock_return",
        "swamp_cave_south_magic_temple",
    },
    rainbow_bridge_return = {"rainbow_bridge_return", "charlock_return", "swamp_cave_south", "swamp_cave_south_recovery"},
    charlock_return = {"charlock_return", "rainbow_bridge_return", "swamp_cave_south", "swamp_cave_south_recovery"},
    rimuldar = {
        "rimuldar",
        "rimuldar_swamp_cave_north",
        "rimuldar_magic_temple",
    },
    magic_temple = {
        "magic_temple",
        "magic_temple_swamp_cave_north",
    },
    rimuldar_magic_temple = {"rimuldar_magic_temple", "rimuldar"},
    mountain_cave = {
        "mountain_cave",
        "mountain_cave_swamp_cave_north",
        "mountain_cave_swamp_cave_south",
        "mountain_cave_northwestern_return",
    },
    hauksness = {
        "hauksness",
        "hauksness_cantlin",
        "hauksness_swamp_cave_north",
        "hauksness_swamp_cave_south",
        "hauksness_northwestern_return",
    },
    hauksness_cantlin = {"hauksness_cantlin", "hauksness"},
    cantlin_hauksness = {
        "cantlin_hauksness",
        "cantlin_great_swamp",
        "cantlin_swamp_cave_north",
        "cantlin_swamp_cave_south",
        "cantlin_northwestern_return",
    },
    great_swamp_cantlin = {
        "great_swamp_cantlin",
        "great_swamp_swamp_cave_north",
        "great_swamp_swamp_cave_south",
        "great_swamp_northwestern_return",
    },
    northwestern_kol_return_staging = {
        "kol_rain_shrine_staging",
        "kol_return_staging",
    },
    hauksness_return_staging = {
        "hauksness_return_staging",
        "mountain_cave_return",
    },
    tantegel = {
        "tantegel",
        "tantegel_kol",
        "tantegel_northern_cave",
        "tantegel_swamp_cave_north",
        "tantegel_rimuldar",
        "tantegel_charlock",
        "tantegel_magic_temple",
    },
    tantegel_kol = {
        "tantegel",
        "tantegel_kol",
        "tantegel_northern_cave",
        "tantegel_swamp_cave_north",
        "tantegel_rimuldar",
        "tantegel_charlock",
        "tantegel_magic_temple",
    },
}

for _, route in pairs(ROUTES) do
    local destination_map_lookup = {}
    for _, map_id in ipairs(route.destination_maps or {}) do
        destination_map_lookup[tonumber(map_id)] = true
    end
    route.destination_map_lookup = destination_map_lookup
end

local alias_to_id = {}
for _, id in ipairs(ROUTE_IDS) do
    local route = ROUTES[id]
    alias_to_id[id] = id
    for _, alias in ipairs(route.aliases or {}) do
        alias_to_id[alias] = id
    end
end
alias_to_id["safe"] = "safety"
alias_to_id["safety"] = "safety"

local state = rawget(_G, "DW_OVERWORLD_ROUTE_STATE")
if type(state) ~= "table" then
    state = {
        active_id = nil,
        next_index = nil,
        staged_from = nil,
        staged_route_ids = {},
        warned = {},
        last_map_id = nil,
        last_x = nil,
        last_y = nil,
    }
    _G.DW_OVERWORLD_ROUTE_STATE = state
end
if type(state.warned) ~= "table" then
    state.warned = {}
end
if type(state.staged_route_ids) ~= "table" then
    state.staged_route_ids = {}
end

local function normalize_route_id(value)
    value = tostring(value or "erdrick"):lower()
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    value = value:gsub("['`]", "")
    if value == "" then
        value = "erdrick"
    end
    return alias_to_id[value]
end

local function normalize_label(value)
    value = tostring(value or ""):lower()
    value = value:gsub("['`]", "")
    value = value:gsub("[^%w]+", " ")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value
end

local function direction_string(px, py, tx, ty)
    if px == tx and py == ty then
        return "here"
    end

    local parts = {}
    if ty < py then
        parts[#parts + 1] = (py - ty) .. " north"
    elseif ty > py then
        parts[#parts + 1] = (ty - py) .. " south"
    end
    if tx > px then
        parts[#parts + 1] = (tx - px) .. " east"
    elseif tx < px then
        parts[#parts + 1] = (px - tx) .. " west"
    end
    return table.concat(parts, ", ")
end

local function append_axis_steps(steps, axis, px, py, tx, ty)
    if axis == "vertical" then
        while py ~= ty do
            if ty < py then
                steps[#steps + 1] = "up"
                py = py - 1
            else
                steps[#steps + 1] = "down"
                py = py + 1
            end
        end
    elseif axis == "horizontal" then
        while px ~= tx do
            if tx < px then
                steps[#steps + 1] = "left"
                px = px - 1
            else
                steps[#steps + 1] = "right"
                px = px + 1
            end
        end
    end

    return px, py
end

local function waypoint_axis_order(route, point, opts)
    opts = opts or {}
    return point and point.axis_order or route and route.axis_order or opts.axis_order or {"vertical", "horizontal"}
end

local function build_axis_ordered_steps(route, point, px, py, opts)
    local steps = {}
    local cx = px
    local cy = py

    for _, axis in ipairs(waypoint_axis_order(route, point, opts)) do
        cx, cy = append_axis_steps(
            steps, axis, cx, cy, point.x, point.y)
    end
    if cx ~= point.x then
        cx, cy = append_axis_steps(
            steps, "horizontal", cx, cy, point.x, point.y)
    end
    if cy ~= point.y then
        cx, cy = append_axis_steps(
            steps, "vertical", cx, cy, point.x, point.y)
    end

    return steps
end

local function position_is_on_route_corridor(route, px, py)
    if not route or not route.waypoints or px == nil or py == nil then
        return false
    end

    local first = route.waypoints[1]
    if first and px == first.x and py == first.y then
        return true
    end

    for index = 2, #route.waypoints do
        local previous = route.waypoints[index - 1]
        local point = route.waypoints[index]
        local x, y = previous.x, previous.y
        for _, step in ipairs(build_axis_ordered_steps(route, point, x, y)) do
            if step == "up" then
                y = y - 1
            elseif step == "down" then
                y = y + 1
            elseif step == "left" then
                x = x - 1
            elseif step == "right" then
                x = x + 1
            end
            if px == x and py == y then
                return true
            end
        end
    end

    return false
end

local function preview_final_carry(route, index, opts)
    local point = route and route.waypoints and route.waypoints[index]
    local next_point =
        route and route.waypoints and route.waypoints[index + 1]
    if not point
       or point.final == true
       or point.route_accept_final_drift_completion == false
       or not next_point then
        return nil, nil
    end

    local steps = build_axis_ordered_steps(
        route, next_point, point.x, point.y, opts)
    local first = steps[1]
    if first == "up" then
        return point.x, point.y - 1
    elseif first == "down" then
        return point.x, point.y + 1
    elseif first == "left" then
        return point.x - 1, point.y
    elseif first == "right" then
        return point.x + 1, point.y
    end
    return nil, nil
end

local function distance(px, py, point)
    return math.abs((px or 0) - point.x) + math.abs((py or 0) - point.y)
end

-- terrain_offset is optional; when supplied, callers benefit from the
-- canonical maps.is_overworld() rule (terrain_offset==0 also counts as
-- overworld, which avoids single-frame disagreement during map transitions).
local function is_overworld(map_id, terrain_offset)
    return maps.is_overworld(tonumber(map_id), terrain_offset)
end

local function is_destination_map(route, map_id)
    return route and route.destination_map_lookup and route.destination_map_lookup[tonumber(map_id)] == true
end

local function active_route()
    return state.active_id and ROUTES[state.active_id] or nil
end

local function staged_destination_route()
    local route = state.staged_from and ROUTES[state.staged_from] or nil
    if route
       and route.staging
       and (route.continue_after_staging == true
            or route.staging.continue_after_staging == true) then
        return route
    end
    return nil
end

function M.active_route_id()
    return state.active_id
end

local function clamp_next_index(route)
    if not route then return nil end
    local count = #route.waypoints
    local index = tonumber(state.next_index) or 1
    if index < 1 then index = 1 end
    if index > count then index = count end
    state.next_index = index
    return index
end

local function choose_next_index(route, map_id, px, py, terrain_offset)
    if not route or not is_overworld(map_id, terrain_offset) or px == nil or py == nil then
        return 1
    end

    local nearest_index = 1
    local nearest_distance = nil
    for i, point in ipairs(route.waypoints) do
        local d = distance(px, py, point)
        if nearest_distance == nil or d < nearest_distance or (d == nearest_distance and i > nearest_index) then
            nearest_index = i
            nearest_distance = d
        end
    end

    local nearest = route.waypoints[nearest_index]
    if nearest_distance <= (nearest.radius or 0) and nearest_index < #route.waypoints then
        return nearest_index + 1
    end
    return nearest_index
end

local function route_start_score(route, map_id, px, py, terrain_offset)
    if not route then
        return math.huge
    end
    local index = choose_next_index(route, map_id, px, py, terrain_offset)
    if route.selection_max_index and index > route.selection_max_index then
        return math.huge
    end
    local point = route.waypoints[index]
    if not point then
        return math.huge
    end
    return distance(px, py, point)
end

local function route_selection_score(route, map_id, px, py, terrain_offset)
    local score = route_start_score(route, map_id, px, py, terrain_offset)
    for _, point in ipairs(route and route.selection_anchors or {}) do
        local anchor_distance = distance(px, py, point)
        if point.max_distance == nil
           or anchor_distance <= point.max_distance then
            score = math.min(score, anchor_distance)
        end
    end
    return score
end

local function choose_best_route_id(ids, map_id, px, py, terrain_offset)
    local fallback = ids and ids[1]
    if not is_overworld(map_id, terrain_offset) or px == nil or py == nil then
        return fallback
    end

    local best_id = fallback
    local best_score = nil
    for _, id in ipairs(ids or {}) do
        local score = route_selection_score(
            ROUTES[id], map_id, px, py, terrain_offset)
        if best_score == nil or score < best_score then
            best_id = id
            best_score = score
        end
    end
    return best_id
end

local function choose_start_route_id(id, map_id, px, py, terrain_offset)
    return choose_best_route_id(ROUTE_ALTERNATES[id] or {id}, map_id, px, py, terrain_offset)
end

local function choose_staging_route_id(staging, map_id, px, py, terrain_offset)
    local ids = ROUTE_ALTERNATES[staging.route_id] or {staging.route_id}
    if staging.prefer_staging_route_corridor then
        local corridor_ids = {}
        for _, candidate_id in ipairs(ids) do
            if position_is_on_route_corridor(ROUTES[candidate_id], px, py) then
                corridor_ids[#corridor_ids + 1] = candidate_id
            end
        end
        if #corridor_ids > 0 then
            ids = corridor_ids
        end
    end
    return choose_best_route_id(ids, map_id, px, py, terrain_offset)
end

local function staging_start_for(id, map_id, px, py, terrain_offset)
    local route = ROUTES[id]
    local staging = route and route.staging
    if not staging or not is_overworld(map_id, terrain_offset) or px == nil or py == nil then
        return nil
    end

    local close_enough = true
    local start_score = route_start_score(route, map_id, px, py, terrain_offset)
    if staging.max_start_distance and start_score > staging.max_start_distance then
        close_enough = false
    end
    if staging.min_x and px < staging.min_x then
        close_enough = false
    end
    if staging.max_x and px > staging.max_x then
        close_enough = false
    end
    if staging.min_y and py < staging.min_y then
        close_enough = false
    end
    if staging.max_y and py > staging.max_y then
        close_enough = false
    end
    local final = route.waypoints and route.waypoints[#route.waypoints]
    local near_destination = final
        and staging.near_destination_snap_distance
        and distance(px, py, final)
            <= staging.near_destination_snap_distance
    if staging.require_route_corridor
       and not near_destination
       and not position_is_on_route_corridor(route, px, py) then
        close_enough = false
    end
    if close_enough then
        return nil
    end

    local fallback_id = choose_staging_route_id(staging, map_id, px, py, terrain_offset)
    if not fallback_id or fallback_id == id or not ROUTES[fallback_id] then
        return nil
    end

    local requested_route = route
    if staging.continuation_route_id and ROUTES[staging.continuation_route_id] then
        requested_route = ROUTES[staging.continuation_route_id]
    end

    return {
        requested_route = requested_route,
        route_id = fallback_id,
    }
end

local function staging_itinerary_for(id, map_id, px, py, terrain_offset)
    local route_id = id
    local staged_route_ids = {}
    local seen = {}

    while route_id and not seen[route_id] do
        seen[route_id] = true
        local staging = staging_start_for(
            route_id, map_id, px, py, terrain_offset)
        if not staging then
            break
        end

        -- Each newly discovered fallback is earlier in the journey. Insert
        -- its requested continuation at the front so handoffs remain ordered.
        table.insert(staged_route_ids, 1, staging.requested_route.id)
        route_id = staging.route_id
    end

    if #staged_route_ids == 0 then
        return nil
    end

    return {
        route_id = route_id,
        requested_route = ROUTES[staged_route_ids[#staged_route_ids]],
        staged_route_ids = staged_route_ids,
    }
end

local function waypoint_status(route, index, px, py)
    if not route or not index then
        return "No overworld route active"
    end
    local point = route.waypoints[index]
    if not point then
        return "Route to " .. route.title .. " complete"
    end

    if px == nil or py == nil then
        return "Route to " .. route.title .. ". Next: " .. point.name
    end

    return string.format(
        "Route to %s. Next: %s, %s",
        route.title,
        point.name,
        direction_string(px, py, point.x, point.y))
end

local function staged_waypoint_status(route, requested_route, index, px, py)
    local point = route and route.waypoints and route.waypoints[index] or nil
    local prefix = string.format(
        "Current leg to %s. Final destination: %s.",
        tostring(route and route.title or "waypoint"),
        tostring(requested_route and requested_route.title or "destination"))
    if not point then
        return prefix
    end
    if px == nil or py == nil then
        return prefix .. " Next: " .. point.name
    end
    return string.format(
        "%s Next: %s, %s",
        prefix,
        point.name,
        direction_string(px, py, point.x, point.y))
end

local function make_log(event, route, point, index)
    return string.format(
        "event=%s route=%s waypoint=%s index=%s",
        tostring(event),
        route and route.id or "-",
        point and point.name or "-",
        tostring(index or state.next_index))
end

local function route_object_id(route, index)
    if not route or not index then
        return nil
    end
    return string.format("route_%s_%02d", route.id, index)
end

local function route_final_waypoint(route)
    if not route or not route.waypoints then
        return nil
    end
    return route.waypoints[#route.waypoints]
end

local function handoff_staged_route(completed_route, completed_point, map_id, px, py, terrain_offset)
    local final_route = staged_destination_route()
    local next_route_id = state.staged_route_ids[1]
    local requested_route = next_route_id and ROUTES[next_route_id] or final_route
    if not requested_route then
        return nil
    end

    local anchor_x = px
    local anchor_y = py
    -- Map ID changes before terrain_offset settles during some town transitions.
    -- A known destination map is authoritative, so anchor the next leg outside.
    if is_destination_map(completed_route, map_id) or not is_overworld(map_id, terrain_offset) then
        anchor_x = completed_point and completed_point.x or px
        anchor_y = completed_point and completed_point.y or py
    end

    state.active_id = requested_route.id
    if next_route_id then
        table.remove(state.staged_route_ids, 1)
    end
    if #state.staged_route_ids == 0 then
        state.staged_from = nil
    end
    state.warned = {}
    state.last_map_id = map_id
    state.last_x = px
    state.last_y = py
    state.next_index = choose_next_index(
        requested_route, WORLD_MAP_ID, anchor_x, anchor_y, terrain_offset)

    local next_point = requested_route.waypoints[state.next_index]
    local message
    if final_route and requested_route.id ~= final_route.id then
        message = string.format(
            "Reached %s. Continuing toward %s. %s",
            tostring(completed_point and completed_point.name
                or completed_route and completed_route.title
                or "staging point"),
            tostring(final_route.title),
            staged_waypoint_status(
                requested_route, final_route, state.next_index, anchor_x, anchor_y))
    else
        message = string.format(
            "Reached %s. Continuing to %s. %s",
            tostring(completed_point and completed_point.name
                or completed_route and completed_route.title
                or "staging point"),
            tostring(requested_route.title),
            waypoint_status(requested_route, state.next_index, anchor_x, anchor_y))
    end
    local log = make_log("handoff", requested_route, next_point, state.next_index)
        .. " from_route=" .. tostring(completed_route and completed_route.id or "-")
    if state.staged_from then
        log = log .. " staged_from=" .. tostring(state.staged_from)
            .. " remaining_legs=" .. tostring(#state.staged_route_ids)
    end
    return {
        status = "handoff",
        route = requested_route,
        completed_route = completed_route,
        waypoint = next_point,
        message = message,
        log = log,
        object_id = route_object_id(requested_route, state.next_index),
        refresh = true,
    }
end

local function clear_active_route()
    state.active_id = nil
    state.next_index = nil
    state.staged_from = nil
    state.staged_route_ids = {}
    state.warned = {}
    state.last_map_id = nil
    state.last_x = nil
    state.last_y = nil
end

local function finish_route(route, point, event)
    local index = state.next_index
    clear_active_route()
    return {
        route = route,
        waypoint = point,
        message = "Arrived at " .. tostring(point and point.name or route and route.title or "destination"),
        log = make_log(event or "arrived", route, point, index),
        refresh = true,
        terminal = true,
    }
end

local function object_matches_route(route, obj)
    if not route or not obj then
        return false
    end
    if obj.route_id == route.id then
        return true
    end
    if obj.id then
        for _, object_id in ipairs(route.target_object_ids or {}) do
            if obj.id == object_id then
                return true
            end
        end
    end

    local final = route_final_waypoint(route)
    if final and tonumber(obj.x) == final.x and tonumber(obj.y) == final.y then
        return true
    end

    return normalize_label(obj.name) == normalize_label(route.title)
end

function M.route_id_for_object(obj, map_id, px, py, terrain_offset)
    local matches = {}
    for _, id in ipairs(ROUTE_IDS) do
        local route = ROUTES[id]
        if object_matches_route(route, obj) then
            matches[#matches + 1] = id
        end
    end
    return choose_best_route_id(matches, map_id, px, py, terrain_offset)
end

local function route_destinations_match(a, b)
    if not a or not b then
        return false
    end
    if a.id == b.id then
        return true
    end
    local function ids_overlap(a_ids, b_ids)
        for _, a_id in ipairs(a_ids or {}) do
            for _, b_id in ipairs(b_ids or {}) do
                if a_id == b_id then
                    return true
                end
            end
        end
        return false
    end
    if ids_overlap(a.target_object_ids, b.target_object_ids)
       or ids_overlap(a.compatible_target_object_ids, b.target_object_ids)
       or ids_overlap(a.target_object_ids, b.compatible_target_object_ids) then
        return true
    end
    return false
end

function M.active_route_matches_object(obj)
    local route = active_route()
    if object_matches_route(route, obj) then
        return true
    end

    if object_matches_route(staged_destination_route(), obj) then
        return true
    end

    -- Compatibility IDs bind a physical Travel object to an already active
    -- route without making that route eligible to start from the object.
    -- Return routes use this when object refresh keeps the departure landmark
    -- selected after the player exits an interior map.
    if route and obj and obj.id then
        for _, object_id in ipairs(route.compatible_target_object_ids or {}) do
            if obj.id == object_id then
                return true
            end
        end
    end

    return false
end

function M.start(route_name, map_id, px, py, opts)
    opts = opts or {}
    local terrain_offset = opts.terrain_offset
    local id = normalize_route_id(route_name)
    if not id then
        return nil, "Unknown overworld route"
    end
    id = choose_start_route_id(id, map_id, px, py, terrain_offset)
    local staging = staging_itinerary_for(id, map_id, px, py, terrain_offset)
    if staging then
        id = staging.route_id
    end

    local route = ROUTES[id]
    local previous_id = state.active_id
    local event = "start"
    if previous_id == id then
        event = "recalculate"
    elseif previous_id ~= nil then
        event = "replace"
    end

    state.active_id = id
    state.staged_from = staging and staging.requested_route.id or nil
    state.staged_route_ids = staging and staging.staged_route_ids or {}
    state.warned = {}
    state.last_map_id = nil
    state.last_x = nil
    state.last_y = nil
    state.next_index = choose_next_index(route, map_id, px, py, terrain_offset)

    local message = waypoint_status(route, state.next_index, is_overworld(map_id, terrain_offset) and px or nil, is_overworld(map_id, terrain_offset) and py or nil)
    if event == "replace" then
        message = "Route changed. " .. message
    elseif event == "recalculate" then
        message = "Route recalculated. " .. message
    end
    if staging then
        message = string.format(
            "%s route starts from %s. Starting route to %s first. %s",
            staging.requested_route.title,
            route.title,
            route.title,
            message)
    end

    local log = make_log(event, route, route.waypoints[state.next_index])
    if staging then
        log = log .. " staged_from=" .. tostring(staging.requested_route.id)
    end

    return {
        route = route,
        message = message,
        log = log,
        object_id = route_object_id(route, state.next_index),
        refresh = true,
    }
end

function M.start_for_object(obj, map_id, px, py, opts)
    opts = opts or {}
    if not obj then
        return nil, "No object selected"
    end

    local id = M.route_id_for_object(obj, map_id, px, py, opts.terrain_offset)
    if not id then
        return nil, "No guided route for " .. tostring(obj.name or "selected object") .. ". Use O for heading."
    end

    return M.start(id, map_id, px, py, opts)
end

function M.stop()
    if not state.active_id then
        return {
            message = "No overworld route active",
            log = "event=stop route=none",
            refresh = false,
        }
    end

    local route = active_route()
    clear_active_route()

    return {
        route = route,
        message = "Stopped overworld route",
        log = "event=stop route=" .. tostring(route and route.id or "-"),
        refresh = true,
    }
end

function M.status(map_id, px, py, opts)
    opts = opts or {}
    local terrain_offset = opts.terrain_offset
    local route = active_route()
    if not route then
        return {
            message = "No overworld route active",
            log = "event=status route=none",
        }
    end

    local index = clamp_next_index(route)
    local recalculated = false
    if opts.recalculate and is_overworld(map_id, terrain_offset) and px ~= nil and py ~= nil then
        local new_route_id
        local new_staged_from = state.staged_from
        local new_staged_route_ids = state.staged_route_ids
        local immediate_staged_id = state.staged_route_ids[1] or new_staged_from
        local requested_route = immediate_staged_id and ROUTES[immediate_staged_id]
        if requested_route and requested_route.staging then
            new_route_id = choose_staging_route_id(
                requested_route.staging, map_id, px, py, terrain_offset)
        else
            new_route_id = choose_start_route_id(route.id, map_id, px, py, terrain_offset)
            local new_staging = staging_itinerary_for(
                new_route_id, map_id, px, py, terrain_offset)
            if new_staging then
                new_route_id = new_staging.route_id
                new_staged_from = new_staging.requested_route.id
                new_staged_route_ids = new_staging.staged_route_ids
            else
                new_staged_from = nil
                new_staged_route_ids = {}
            end
        end
        if new_route_id and new_route_id ~= state.active_id then
            state.active_id = new_route_id
            state.staged_from = new_staged_from
            state.staged_route_ids = new_staged_route_ids
            state.warned = {}
            route = active_route()
            index = choose_next_index(route, map_id, px, py, terrain_offset)
            state.next_index = index
            state.last_map_id = nil
            state.last_x = nil
            state.last_y = nil
            recalculated = true
        end
        local new_index = choose_next_index(route, map_id, px, py, terrain_offset)
        if new_index ~= index then
            state.next_index = new_index
            state.last_map_id = nil
            state.last_x = nil
            state.last_y = nil
            index = new_index
            recalculated = true
        end
    end

    local use_position = is_overworld(map_id, terrain_offset)
    local message = waypoint_status(route, index, use_position and px or nil, use_position and py or nil)
    local requested_route = staged_destination_route()
    if requested_route then
        message = staged_waypoint_status(
            route,
            requested_route,
            index,
            use_position and px or nil,
            use_position and py or nil)
    end
    if recalculated or opts.force_recalculate_message then
        message = "Route recalculated. " .. message
    end

    return {
        route = route,
        waypoint = route.waypoints[index],
        message = message,
        log = make_log(recalculated and "recalculate" or "status", route, route.waypoints[index]),
        object_id = route_object_id(route, index),
    }
end

function M.recalculate(map_id, px, py, opts)
    opts = opts or {}
    return M.status(map_id, px, py, {
        recalculate = true,
        force_recalculate_message = true,
        terrain_offset = opts.terrain_offset,
    })
end

function M.plan_next_segment(map_id, px, py, opts)
    opts = opts or {}
    local route = active_route()
    if not route then
        return nil, "No overworld route active"
    end
    if not is_overworld(map_id, opts.terrain_offset) then
        return nil, "Overworld auto-walk is only available on the world map"
    end
    if px == nil or py == nil then
        return nil, "Current world-map position unavailable"
    end

    local index = clamp_next_index(route)
    local point = route.waypoints[index]
    if not point then
        return nil, "No next overworld waypoint"
    end

    -- "Already at waypoint" without advance_if_at_waypoint returns a status-only
    -- record. With it, advance one slot and replan so a single autowalk press
    -- doesn't stall the route when the player is sitting exactly on a waypoint.
    -- Bail at the final waypoint — observe_position handles arrival.
    if distance(px, py, point) <= (point.radius or 0) then
        if opts.advance_if_at_waypoint and index < #route.waypoints then
            state.next_index = index + 1
            return M.plan_next_segment(map_id, px, py, opts)
        end
        return {
            route = route,
            waypoint = point,
            index = index,
            steps = {},
            path_length = 0,
            status = "already_at_waypoint",
            message = "Already at " .. point.name,
            log = make_log("autowalk_already", route, point, index),
            object_id = route_object_id(route, index),
            refresh = true,
        }
    end
    local direction = direction_string(px, py, point.x, point.y)

    local steps = build_axis_ordered_steps(route, point, px, py, opts)

    local max_steps = tonumber(opts.max_steps) or 64
    if #steps > max_steps then
        return nil, string.format("Overworld segment too long: %d steps", #steps)
    end
    local route_final_carry_x, route_final_carry_y =
        preview_final_carry(route, index, opts)

    return {
        route = route,
        waypoint = point,
        index = index,
        steps = steps,
        path_length = #steps,
        route_final_carry_x = route_final_carry_x,
        route_final_carry_y = route_final_carry_y,
        status = "planned",
        direction = direction,
        message = string.format("Auto-walk to %s, %s. %d step(s).", point.name, direction, #steps),
        log = make_log("autowalk_plan", route, point, index),
        object_id = route_object_id(route, index),
    }
end

function M.guidance_for_object(obj, map_id, px, py, opts)
    opts = opts or {}
    local route = active_route()
    if route then
        local selected_id = M.route_id_for_object(obj, map_id, px, py, opts.terrain_offset)
        local requested_route = staged_destination_route()
        if selected_id
           and not route_destinations_match(route, ROUTES[selected_id])
           and not route_destinations_match(requested_route, ROUTES[selected_id]) then
            return M.start(selected_id, map_id, px, py, opts)
        end

        -- A compatible landmark is bound to the active itinerary only so a
        -- Travel refresh cannot replace the player's final destination. Do not
        -- recalculate from that landmark: an adjacent first waypoint can look
        -- off-corridor and incorrectly restage the active route back to it.
        local compatibility_only = M.active_route_matches_object(obj)
            and not object_matches_route(route, obj)
            and not object_matches_route(requested_route, obj)
        return M.status(map_id, px, py, {
            recalculate = not compatibility_only,
            terrain_offset = opts.terrain_offset,
        })
    end

    return M.start_for_object(obj, map_id, px, py, opts)
end

function M.observe_position(map_id, px, py, terrain_offset)
    local route = active_route()
    if not route then
        return nil
    end

    if is_destination_map(route, map_id) then
        local final = route_final_waypoint(route)
        return handoff_staged_route(route, final, map_id, px, py, terrain_offset)
            or finish_route(route, final, "arrived")
    end

    if not is_overworld(map_id, terrain_offset) or px == nil or py == nil then
        return nil
    end

    if state.last_map_id == map_id and state.last_x == px and state.last_y == py then
        return nil
    end
    state.last_map_id = map_id
    state.last_x = px
    state.last_y = py

    local index = clamp_next_index(route)
    local point = route.waypoints[index]
    if not point then
        return nil
    end

    if distance(px, py, point) > (point.radius or 0) then
        return nil
    end

    local messages = {}
    local warning_message = nil
    if point.warning and not state.warned[index] then
        messages[#messages + 1] = point.warning
        warning_message = point.warning
        state.warned[index] = true
    end

    if point.final then
        if route.staged_handoff_requires_destination_map == true
           and staged_destination_route() then
            if #messages == 0 then
                messages[1] = route.staged_transition_message
                    or "Use the map transition to continue this route."
            end
            return {
                status = "await_transition",
                route = route,
                waypoint = point,
                message = table.concat(messages, " "),
                warning_message = warning_message,
                log = make_log("await_transition", route, point, index),
                object_id = route_object_id(route, index),
                refresh = true,
            }
        end
        local event = handoff_staged_route(route, point, map_id, px, py, terrain_offset)
            or finish_route(route, point, "arrived")
        if #messages > 0 then
            event.message = table.concat(messages, " ") .. " " .. event.message
        end
        event.warning_message = warning_message
        return event
    end

    state.next_index = math.min(index + 1, #route.waypoints)
    local next_point = route.waypoints[state.next_index]
    messages[#messages + 1] = "Reached " .. point.name .. ". Next: " .. next_point.name .. ", " ..
        direction_string(px, py, next_point.x, next_point.y)

    return {
        route = route,
        waypoint = point,
        message = table.concat(messages, " "),
        warning_message = warning_message,
        log = make_log("advance", route, point),
        object_id = route_object_id(route, state.next_index),
        refresh = true,
    }
end

function M.get_active_waypoint_objects()
    local route = active_route()
    if not route then
        return {}
    end

    local index = clamp_next_index(route)
    local result = {}
    local last_visible = math.min(#route.waypoints, index + MAX_VISIBLE_ACTIVE_WAYPOINTS - 1)
    for i = index, last_visible do
        local point = route.waypoints[i]
        local prefix = (i == index) and "Route next: " or "Route later: "
        result[#result + 1] = {
            x = point.x,
            y = point.y,
            name = prefix .. point.name,
            type = "exit",
            id = string.format("route_%s_%02d", route.id, i),
            route_id = route.id,
            route_waypoint = true,
            route_index = i,
            route_final = point.final == true,
        }
    end
    return result
end

function M.get_active_next_object_id()
    local route = active_route()
    if not route then
        return nil
    end
    return route_object_id(route, clamp_next_index(route))
end

function M.is_active()
    return active_route() ~= nil
end

function M.reset_for_tests()
    state.active_id = nil
    state.next_index = nil
    state.staged_from = nil
    state.staged_route_ids = {}
    state.warned = {}
    state.last_map_id = nil
    state.last_x = nil
    state.last_y = nil
end

function M._route_for_tests(id)
    return ROUTES[id]
end

function M._preview_final_carry_for_tests(route, index, opts)
    return preview_final_carry(route, index, opts)
end

return M
