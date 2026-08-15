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

local FINAL_PROGRESSION_STAGING = {
    route_id = "swamp_cave_south",
    -- The longest validated bridge-road segment is eleven tiles. Starts
    -- farther from the final-progression routes must first use the established
    -- Rimuldar-to-south-cave waypoint chain instead of synthesizing a shortcut.
    -- Nearby off-corridor starts must stage too, and should prefer whichever
    -- established approach/return route already contains their position.
    max_start_distance = 11,
    require_route_corridor = true,
    prefer_staging_route_corridor = true,
}

local MAGIC_TEMPLE_STAGING = {
    route_id = "rimuldar",
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
    require_route_corridor = true,
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
            {x = 48, y = 41, name = "Brecconary road", radius = 1},
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
            {x = 78, y = 3, name = "Rain shrine island approach", radius = 1},
            {x = 77, y = 3, name = "Rain shrine island west lane", radius = 0},
            {x = 77, y = 4, name = "Rain shrine island lower step", radius = 0},
            {x = 76, y = 4, name = "Rain shrine northwest coast lane", radius = 0},
            {x = 76, y = 5, name = "Rain shrine northwest coast step", radius = 0},
            {x = 75, y = 5, name = "Rain shrine west coast north road", radius = 1},
            {x = 75, y = 14, name = "Rain shrine west coast turn", radius = 0},
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
        waypoints = {
            {
                x = 104,
                y = 49,
                name = "Swamp Cave South Entrance",
                radius = 1,
                warning = "Guide-derived Rimuldar route. The west route is safer but still needs live validation.",
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
                warning = "Return route still needs live validation from this side.",
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
            {x = 48, y = 41, name = "Brecconary road", radius = 1},
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

-- Internal staging leg: reuse the live-validated Hauksness corridor from Kol
-- only through the Mountain Cave junction. Keeping this derived avoids a
-- second manually maintained copy of more than sixty waypoint turns.
ROUTES.mountain_cave_connector = {
    id = "mountain_cave_connector",
    title = "Western desert east road",
    staging = MOUNTAIN_CAVE_CONNECTOR_STAGING,
    waypoints = copy_route_prefix(ROUTES.hauksness, 18, 64),
}

-- Keep lookup deterministic, especially when several routes share a Travel target.
local ROUTE_IDS = {
    "brecconary",
    "garinham",
    "kol",
    "northern_cave",
    "kol_rain_shrine",
    "kol_swamp_cave",
    "kol_hauksness",
    "swamp_cave",
    "swamp_cave_bridge",
    "rimuldar",
    "magic_temple",
    "rimuldar_magic_temple",
    "swamp_cave_south",
    "swamp_cave_south_recovery",
    "rainbow_bridge",
    "rainbow_bridge_return",
    "charlock_castle",
    "charlock_return",
    "mountain_cave",
    "mountain_cave_return",
    "hauksness",
    "hauksness_cantlin",
    "cantlin_hauksness",
    "great_swamp_cantlin",
    "cantlin_great_swamp",
    "erdrick",
    "tantegel",
    "tantegel_kol",
}

local ROUTE_ALTERNATES = {
    safety = {"brecconary", "tantegel"},
    kol = {"kol", "kol_rain_shrine", "kol_swamp_cave", "kol_hauksness"},
    kol_rain_shrine = {"kol", "kol_rain_shrine", "kol_swamp_cave", "kol_hauksness"},
    kol_swamp_cave = {"kol_swamp_cave", "kol", "kol_rain_shrine", "kol_hauksness"},
    kol_hauksness = {"kol_hauksness", "kol", "kol_rain_shrine", "kol_swamp_cave"},
    swamp_cave = {"swamp_cave_bridge", "swamp_cave"},
    swamp_cave_bridge = {"swamp_cave_bridge", "swamp_cave"},
    swamp_cave_south = {"swamp_cave_south", "swamp_cave_south_recovery", "rainbow_bridge_return", "charlock_return"},
    swamp_cave_south_recovery = {"swamp_cave_south", "swamp_cave_south_recovery", "rainbow_bridge_return", "charlock_return"},
    rainbow_bridge_return = {"rainbow_bridge_return", "charlock_return", "swamp_cave_south", "swamp_cave_south_recovery"},
    charlock_return = {"charlock_return", "rainbow_bridge_return", "swamp_cave_south", "swamp_cave_south_recovery"},
    rimuldar = {"rimuldar", "rimuldar_magic_temple"},
    rimuldar_magic_temple = {"rimuldar_magic_temple", "rimuldar"},
    hauksness = {"hauksness", "hauksness_cantlin"},
    hauksness_cantlin = {"hauksness_cantlin", "hauksness"},
    cantlin_hauksness = {"cantlin_hauksness", "cantlin_great_swamp"},
    tantegel = {"tantegel", "tantegel_kol"},
    tantegel_kol = {"tantegel", "tantegel_kol"},
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

local function choose_best_route_id(ids, map_id, px, py, terrain_offset)
    local fallback = ids and ids[1]
    if not is_overworld(map_id, terrain_offset) or px == nil or py == nil then
        return fallback
    end

    local best_id = fallback
    local best_score = nil
    for _, id in ipairs(ids or {}) do
        local score = route_start_score(ROUTES[id], map_id, px, py, terrain_offset)
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
    if staging.require_route_corridor and not position_is_on_route_corridor(route, px, py) then
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
        return M.status(map_id, px, py, {
            recalculate = true,
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
