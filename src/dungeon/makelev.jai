// MakeLev - Original Incursion dungeon generation
//
// This is a faithful translation of MakeLev.cpp to produce identical
// dungeons given the same RNG seed.
//
// Reference: C:\Data\R\roguelike - incursion\repo-work\src\MakeLev.cpp
//
// Note: This file is loaded by main.jai which handles all imports.

// Global flag to suppress debug/progress messages
makelev_quiet := false;

// Tunnel termination flags (from original MakeLev.cpp)
// These control when a tunnel should stop
TT_CONNECT   :: 0x01;  // Terminate when reach area where Connected flag differs from start
TT_DIRECT    :: 0x02;  // Always take the most direct route to destination
TT_LENGTH    :: 0x04;  // Terminate if length exceeds given value
TT_NOTOUCH   :: 0x08;  // Don't "touch" rooms during traversal
TT_EXACT     :: 0x10;  // Go to *exact* destination coordinates
TT_WANDER    :: 0x20;  // Chance to end after touching 2 rooms
TT_NATURAL   :: 0x40;  // Curved, natural, non-horizontal tunnels

// Priority levels for terrain writing (higher priority overwrites lower)
// Source: Defines.h:4307-4320
PRIO_EMPTY          :: 0;
PRIO_ROCK_STREAMER  :: 5;    // Rock veins, mineral deposits
PRIO_CORRIDOR_WALL  :: 10;
PRIO_CORRIDOR_FLOOR :: 30;
PRIO_ROOM_WALL      :: 40;
PRIO_ROOM_FLOOR     :: 70;
PRIO_ROOM_FURNITURE :: 75;   // Between floor and vault
PRIO_VAULT          :: 90;
PRIO_RIVER_STREAMER :: 90;   // Rivers/chasms cut through rooms
PRIO_FEATURE_FLOOR  :: 100;
PRIO_DEPOSIT        :: 110;  // Treasure deposits in walls
PRIO_MAX            :: 120;

// Streamer types (matching original regions with RF_RIVER, RF_CHASM, etc.)
StreamerType :: enum {
    WATER_RIVER;      // Wide water river crossing the map
    WATER_STREAM;     // Narrower water feature
    CHASM;            // Bottomless pit
    LAVA_RIVER;       // Lava flow (not implemented yet, uses CHASM terrain)
    RUBBLE;           // Collapsed area with rough terrain
}

// Streamer type properties
StreamerInfo :: struct {
    terrain: Terrain;
    is_river: bool;     // Starts from edge, constant width
    min_width: s32;
    max_width: s32;
    priority: u8;
}

STREAMER_INFO :: StreamerInfo.[
    .{.WATER, true, 2, 5, PRIO_RIVER_STREAMER},   // WATER_RIVER
    .{.WATER, false, 1, 3, PRIO_ROCK_STREAMER},   // WATER_STREAM
    .{.CHASM, false, 3, 6, PRIO_RIVER_STREAMER},  // CHASM
    .{.LAVA, true, 2, 4, PRIO_RIVER_STREAMER},    // LAVA_RIVER
    .{.ROCK, false, 1, 3, PRIO_ROCK_STREAMER},    // RUBBLE (TODO: add rubble terrain)
];

// Vault structure for pre-designed special rooms
VaultDef :: struct {
    name: string;
    width: s32;
    height: s32;
    map_data: string;    // ASCII art map, row by row
    min_depth: s32;      // Minimum dungeon depth for this vault
}

// Vault definitions (pre-designed special rooms)
// Characters: . = floor, # = wall, + = door, ~ = water, ^ = lava, _ = chasm, > = stairs down, < = stairs up
VAULTS :: VaultDef.[
    .{
        "treasure_room",
        7, 5,
        #string END
#######
#.....#
#..>..#
#.....#
##+####
END,
        3
    },
    .{
        "water_shrine",
        9, 7,
        #string END
#########
#.......#
#.~~~~~.#
#.~~~~~.#
#.~~~~~.#
#.......#
####+####
END,
        2
    },
    .{
        "guard_post",
        9, 9,
        #string END
#########
#...#...#
#...+...#
#...#...#
###+##+##
#...#...#
#...+...#
#...#...#
#########
END,
        1
    },
    .{
        "arena",
        11, 9,
        #string END
###########
#.........#
#.........#
#.........#
+....#....+
#.........#
#.........#
#.........#
###########
END,
        2
    },
    .{
        "library",
        11, 9,
        #string END
###########
#.#.#.#.#.#
#.........#
#.#.#.#.#.#
+.........+
#.#.#.#.#.#
#.........#
#.#.#.#.#.#
###########
END,
        3
    },
    .{
        "throne_room",
        11, 7,
        #string END
###########
#.........#
#..#...#..#
#....#....#
#..#...#..#
#.........#
#####+#####
END,
        4
    },
    .{
        "prison",
        11, 7,
        #string END
###########
#.+.+.+.+.#
#.#######.#
#.........#
#.#######.#
#.+.+.+.+.#
#####+#####
END,
        3
    },
    .{
        "lava_chamber",
        9, 7,
        #string END
#########
#..^^^..#
#.^^^^^.#
+.^^.^^.+
#.^^^^^.#
#..^^^..#
#########
END,
        5
    },
    .{
        "chasm_bridge",
        11, 7,
        #string END
###########
#...___...#
#...___...#
+.........+
#...___...#
#...___...#
###########
END,
        4
    },
    .{
        "altar_room",
        9, 9,
        #string END
#########
#.......#
#.~...~.#
#..#.#..#
#...#...#
#..#.#..#
#.~...~.#
#.......#
####+####
END,
        2
    },
    .{
        "pillared_hall",
        13, 9,
        #string END
#############
#...........#
#.#.......#.#
#...........#
+.#...#...#.+
#...........#
#.#.......#.#
#...........#
#############
END,
        2
    },
    .{
        "crossroads",
        9, 9,
        #string END
#####+###
#.......#
#.#####.#
#.#...#.#
+.+...+.+
#.#...#.#
#.#####.#
#.......#
#####+###
END,
        1
    },
];

// Room type constants (from Defines.h)
RM_ANY       :: -1;
RM_NOROOM    :: 0;   // Empty panel; no room
RM_NORMAL    :: 1;   // Single small square
RM_LARGE     :: 2;   // Large room (1d4 - panel edge)
RM_CROSS     :: 3;   // Two overlapping rectangles
RM_OVERLAP   :: 4;   // 2-4 overlapping squares
RM_ADJACENT  :: 5;   // Four squares with shared center
RM_AD_ROUND  :: 6;   // As ADJACENT, but with circles
RM_AD_MIXED  :: 7;   // As ADJACENT, but with either
RM_CIRCLE    :: 8;   // Just a big circle
RM_OCTAGON   :: 9;   // Roughly rounded room
RM_DOUBLE    :: 10;  // Room within a room
RM_PILLARS   :: 11;  // Room with pillars
RM_CASTLE    :: 12;  // "Castle" / subdivided big room
RM_CHECKER   :: 13;  // Checkerboard
RM_BUILDING  :: 14;  // Large, Subdivided
RM_DESTROYED :: 15;  // Area collapsed; 10% rock, 30% rubble
RM_GRID      :: 16;  // Room filled with furnishings as even grid
RM_LIFECAVE  :: 17;  // Game-of-Life smooth caverns
RM_RCAVERN   :: 18;  // Repeated-L rough caverns
RM_LCIRCLE   :: 19;  // Large Circle
RM_SHAPED    :: 20;  // Special Shapes (resource room maps)
RM_LIFELINK  :: 21;  // Game of Life w. Linked Regions
RM_RANDTOWN  :: 22;  // Small, Random Town in Dungeon
RM_MAZE      :: 23;  // Random Maze fills most of panel
RM_DIAMONDS  :: 24;  // Grid of Diamond squares
RM_LAST      :: 32;

// Dungeon constants (simplified - real version loads from dungeon definition)
DungeonConstants :: struct {
    LEVEL_SIZEX     : s32 : 80;
    LEVEL_SIZEY     : s32 : 50;
    PANEL_SIZEX     : s32 : 20;
    PANEL_SIZEY     : s32 : 25;
    ROOM_MINX       : s32 : 4;
    ROOM_MAXX       : s32 : 12;
    ROOM_MINY       : s32 : 4;
    ROOM_MAXY       : s32 : 10;
    MIN_STAIRS      : s32 : 1;
    MAX_STAIRS      : s32 : 3;
    TERRAIN_ROCK    : Terrain : .ROCK;
    TERRAIN_FLOOR   : Terrain : .FLOOR;
    TERRAIN_WALL    : Terrain : .WALL;
    // Streamer constants (original defaults from Annot.cpp:GetConst)
    MIN_STREAMERS       : s32 : 2;   // Minimum guaranteed streamers per level
    MAX_STREAMERS       : s32 : 4;   // Maximum streamers per level
    STREAMER_CHANCE     : s32 : 70;  // % chance for each additional streamer beyond minimum
    MAX_STREAMER_WIDTH  : s32 : 5;   // Maximum non-river streamer width
    MIN_RIVER_DEPTH     : s32 : 3;   // Minimum depth for river streamers
    MIN_CHASM_DEPTH     : s32 : 5;   // Minimum depth for chasm streamers
    DUN_DEPTH           : s32 : 20;  // Total dungeon depth (no chasms on last level)
    // Corridor constants (original defaults from Annot.cpp:GetConst)
    TURN_CHANCE         : s32 : 10;  // % chance to turn each step after min segment
    SEGMENT_MINLEN      : s32 : 4;   // Minimum segment length before turning
    SEGMENT_MAXLEN      : s32 : 10;  // Maximum segment length before forced turn
    STUBBORN_CORRIDOR   : s32 : 30;  // % chance to NOT correct direction toward target
    MAX_CORRIDOR_LEN    : s32 : 500; // Safety limit
}

// Default constants for standard dungeon
DEFAULT_CON :: DungeonConstants.{};

// Per-cell generation info (matches LocationInfo temp fields in original)
// These are temporary flags used during generation, then cleared
CellInfo :: struct {
    priority: u8;       // What wrote this cell (PRIO_*)
    connected: bool;    // Is this cell connected to the main dungeon?
    solid: bool;        // Is this cell impassable?
}

// Extended Map info for generation (parallel array to map tiles)
MapGenInfo :: struct {
    cells: [MAP_WIDTH * MAP_HEIGHT] CellInfo;
}

// Generation state (matches static vars in MakeLev.cpp)
GenState :: struct {
    con: DungeonConstants;
    panels_x: s32;
    panels_y: s32;
    panels_drawn: [32] u32;      // Bit flags for which panels are drawn
    rooms_touched: [32] u32;     // Bit flags for touched rooms

    // Open spaces for corridor connection
    open_x: [2048] u8;
    open_y: [2048] u8;
    open_count: s32;

    // Room corners and centers for corridor endpoints
    corners: [32] u16;   // x + y*256
    n_corners: s32;
    centers: [16] u16;
    n_centers: s32;

    // Per-cell generation info
    gen_info: MapGenInfo;

    // Flood fill working arrays (allocated on temp allocator)
    flood_array: *u8;
    flood_stack: *u8;

    // Weighted room/region selection (from weights.jai)
    dungeon_weights: DungeonWeights;
    selection: SelectionState;
    current_region: *RuntimeRegion;  // Currently selected region for room appearance

    // Terrain registry for visual variety
    terrain_registry: TerrainRegistry;
    default_floor: *RuntimeTerrain;
    default_wall: *RuntimeTerrain;
}

// Initialize generation state
gen_state_init :: (gs: *GenState, con: DungeonConstants = DEFAULT_CON, depth: s32 = 1) {
    gs.con = con;
    gs.panels_x = con.LEVEL_SIZEX / con.PANEL_SIZEX;
    gs.panels_y = con.LEVEL_SIZEY / con.PANEL_SIZEY;

    for i: 0..31 {
        gs.panels_drawn[i] = 0;
        gs.rooms_touched[i] = 0;
    }

    gs.open_count = 0;
    gs.n_corners = 0;
    gs.n_centers = 0;

    // Initialize per-cell info
    for i: 0..MAP_WIDTH * MAP_HEIGHT - 1 {
        gs.gen_info.cells[i].priority = PRIO_EMPTY;
        gs.gen_info.cells[i].connected = false;
        gs.gen_info.cells[i].solid = true;
    }

    // Initialize terrain registry - try baked terrains first
    db := get_resource_db();
    if db != null && db.terrains.count > 0 {
        build_terrain_registry_from_baked(*gs.terrain_registry, db.terrains);
    } else {
        create_default_terrains(*gs.terrain_registry);
    }
    gs.default_floor = terrain_registry_get(*gs.terrain_registry, "floor");
    gs.default_wall = terrain_registry_get(*gs.terrain_registry, "wall");

    // Initialize weighted selection (uses baked regions if available)
    init_dungeon_weights(*gs.dungeon_weights);
    init_selection_state(*gs.selection, *gs.dungeon_weights, depth);
    gs.current_region = null;

    // Resolve terrain references for all regions
    resolve_region_terrains(*gs.dungeon_weights, *gs.terrain_registry);
}

// Get cell info at position
get_cell :: (gs: *GenState, m: *GenMap, x: s32, y: s32) -> *CellInfo {
    if x < 0 || x >= m.width || y < 0 || y >= m.height return null;
    return *gs.gen_info.cells[y * m.width + x];
}

// Check if position is solid
is_solid :: (gs: *GenState, m: *GenMap, x: s32, y: s32) -> bool {
    t := map_get(m, x, y);
    return terrain_solid(t);
}

// Flood fill to mark all connected tiles starting from (x, y)
// Returns count of tiles marked connected
// In original: int32 Map::FloodConnectA(int16 x, int16 y, int32 fCount)
flood_connect :: (gs: *GenState, m: *GenMap, start_x: s32, start_y: s32) -> s32 {
    count: s32 = 0;

    // Use a stack-based flood fill (iterative to avoid recursion limits)
    stack: [..] Point;
    stack.allocator = temp;

    // Start from the given position
    if is_solid(gs, m, start_x, start_y) return 0;

    start_cell := get_cell(gs, m, start_x, start_y);
    if start_cell == null || start_cell.connected return 0;

    array_add(*stack, Point.{start_x, start_y});

    while stack.count > 0 {
        pos := pop(*stack);
        x := pos.x;
        y := pos.y;

        // Skip if out of bounds or already processed
        cell := get_cell(gs, m, x, y);
        if cell == null continue;
        if cell.connected continue;
        if is_solid(gs, m, x, y) continue;

        // Mark as connected
        cell.connected = true;
        count += 1;

        // Add 4-connected neighbors (treating doors as passable)
        t := map_get(m, x, y);
        if !terrain_solid(t) || t == .DOOR_CLOSED || t == .DOOR_SECRET {
            // Check all 4 directions
            if x > 0 {
                nc := get_cell(gs, m, x-1, y);
                if nc != null && !nc.connected && !is_solid(gs, m, x-1, y) {
                    array_add(*stack, Point.{x-1, y});
                }
            }
            if x < m.width - 1 {
                nc := get_cell(gs, m, x+1, y);
                if nc != null && !nc.connected && !is_solid(gs, m, x+1, y) {
                    array_add(*stack, Point.{x+1, y});
                }
            }
            if y > 0 {
                nc := get_cell(gs, m, x, y-1);
                if nc != null && !nc.connected && !is_solid(gs, m, x, y-1) {
                    array_add(*stack, Point.{x, y-1});
                }
            }
            if y < m.height - 1 {
                nc := get_cell(gs, m, x, y+1);
                if nc != null && !nc.connected && !is_solid(gs, m, x, y+1) {
                    array_add(*stack, Point.{x, y+1});
                }
            }
        }
    }

    return count;
}

// Clear all connected flags
clear_connected :: (gs: *GenState, m: *GenMap) {
    for i: 0..m.width * m.height - 1 {
        gs.gen_info.cells[i].connected = false;
    }
}

// Find unconnected open tiles and return arrays of connected and unconnected edge tiles
// In original, this is the fix-up tunneling step
find_disconnected_regions :: (gs: *GenState, m: *GenMap) -> connected_edges: [..] Point, unconnected_edges: [..] Point {
    connected_edges: [..] Point;
    connected_edges.allocator = temp;

    unconnected_edges: [..] Point;
    unconnected_edges.allocator = temp;

    // Find edge tiles (open tiles adjacent to solid)
    for y: 1..m.height-2 {
        for x: 1..m.width-2 {
            if is_solid(gs, m, x, y) continue;

            // Count open neighbors
            open_count := 0;
            if !is_solid(gs, m, x-1, y) open_count += 1;
            if !is_solid(gs, m, x+1, y) open_count += 1;
            if !is_solid(gs, m, x, y-1) open_count += 1;
            if !is_solid(gs, m, x, y+1) open_count += 1;

            // Edge tile has < 4 open neighbors
            if open_count < 4 {
                cell := get_cell(gs, m, x, y);
                if cell != null {
                    if cell.connected {
                        array_add(*connected_edges, Point.{x, y});
                    } else {
                        array_add(*unconnected_edges, Point.{x, y});
                    }
                }
            }
        }
    }

    return connected_edges, unconnected_edges;
}

// Manhattan distance
dist :: (x1: s32, y1: s32, x2: s32, y2: s32) -> s32 {
    return abs(x1 - x2) + abs(y1 - y2);
}

// Point struct for edge tile lists
Point :: struct {
    x: s32;
    y: s32;
}

// Write terrain at position with priority check
// In original: void Map::WriteAt(Rect &r, int16 x, int16 y, rID terID, rID regID, int8 Pri, bool Force)
write_at :: (m: *GenMap, gs: *GenState, x: s32, y: s32, terrain: Terrain, priority: u8 = PRIO_ROOM_FLOOR, force: bool = false) {
    if !map_in_bounds(m, x, y) return;

    cell := get_cell(gs, m, x, y);
    if cell == null return;

    // Only write if force or higher priority
    if !force && cell.priority > priority return;

    map_set(m, x, y, terrain);
    cell.priority = priority;
    cell.solid = terrain_solid(terrain);
}

// Write terrain at position with custom display from RuntimeTerrain
write_at_with_terrain :: (m: *GenMap, gs: *GenState, x: s32, y: s32, terrain: Terrain, rt: *RuntimeTerrain, priority: u8 = PRIO_ROOM_FLOOR, force: bool = false) {
    if !map_in_bounds(m, x, y) return;

    cell := get_cell(gs, m, x, y);
    if cell == null return;

    // Only write if force or higher priority
    if !force && cell.priority > priority return;

    // Write terrain with custom display info
    if rt != null {
        map_set_with_display(m, x, y, terrain, rt.glyph, rt.fg_color);
    } else {
        map_set(m, x, y, terrain);
    }
    cell.priority = priority;
    cell.solid = terrain_solid(terrain);
}

// Convenience version without GenState for simple cases
write_at :: (m: *GenMap, x: s32, y: s32, terrain: Terrain, priority: s32 = 0, force: bool = false) {
    if !map_in_bounds(m, x, y) return;
    map_set(m, x, y, terrain);
}

// Write a rectangular room floor
// In original: void Map::WriteRoom(Rect &r, rID regID)
write_room :: (m: *GenMap, gs: *GenState, r: Rect) {
    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;

    // Get region terrain (with fallback to defaults)
    floor_terrain := get_region_floor(gs.current_region, gs.default_floor);
    wall_terrain := get_region_wall(gs.current_region, gs.default_wall);

    // Fill interior with floor
    for y: r.y1..r.y2 {
        for x: r.x1..r.x2 {
            write_at_with_terrain(m, gs, x, y, floor, floor_terrain, PRIO_ROOM_FLOOR);
        }
    }

    // Draw walls around it
    for x: r.x1-1..r.x2+1 {
        if map_get(m, x, r.y1-1) == .ROCK  write_at_with_terrain(m, gs, x, r.y1-1, wall, wall_terrain, PRIO_ROOM_WALL);
        if map_get(m, x, r.y2+1) == .ROCK  write_at_with_terrain(m, gs, x, r.y2+1, wall, wall_terrain, PRIO_ROOM_WALL);
    }
    for y: r.y1-1..r.y2+1 {
        if map_get(m, r.x1-1, y) == .ROCK  write_at_with_terrain(m, gs, r.x1-1, y, wall, wall_terrain, PRIO_ROOM_WALL);
        if map_get(m, r.x2+1, y) == .ROCK  write_at_with_terrain(m, gs, r.x2+1, y, wall, wall_terrain, PRIO_ROOM_WALL);
    }

    // Record center for corridors
    if gs.n_centers < 16 {
        cx, cy := rect_center(r);
        gs.centers[gs.n_centers] = cast(u16)(cx + cy * 256);
        gs.n_centers += 1;
    }

    // Record corners
    if gs.n_corners < 28 {
        gs.corners[gs.n_corners] = cast(u16)(r.x1 + r.y1 * 256);
        gs.n_corners += 1;
        gs.corners[gs.n_corners] = cast(u16)(r.x2 + r.y1 * 256);
        gs.n_corners += 1;
        gs.corners[gs.n_corners] = cast(u16)(r.x1 + r.y2 * 256);
        gs.n_corners += 1;
        gs.corners[gs.n_corners] = cast(u16)(r.x2 + r.y2 * 256);
        gs.n_corners += 1;
    }

    // Track this room
    room: Room;
    room.bounds = r;
    room.connected = false;
    array_add(*m.rooms, room);
}

// Write a circular room
// In original: void Map::WriteCircle(Rect &r, rID regID)
write_circle :: (m: *GenMap, gs: *GenState, r: Rect) {
    cx, cy := rect_center(r);
    radius_x := rect_width(r) / 2;
    radius_y := rect_height(r) / 2;
    radius := min(radius_x, radius_y);

    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;

    // Get region terrain (with fallback to defaults)
    floor_terrain := get_region_floor(gs.current_region, gs.default_floor);
    wall_terrain := get_region_wall(gs.current_region, gs.default_wall);

    for y: r.y1-1..r.y2+1 {
        for x: r.x1-1..r.x2+1 {
            dx := x - cx;
            dy := y - cy;
            dist_sq := dx*dx + dy*dy;

            if dist_sq <= radius * radius {
                write_at_with_terrain(m, gs, x, y, floor, floor_terrain, PRIO_ROOM_FLOOR);
            } else if dist_sq <= (radius+1) * (radius+1) {
                if map_get(m, x, y) == .ROCK {
                    write_at_with_terrain(m, gs, x, y, wall, wall_terrain, PRIO_ROOM_WALL);
                }
            }
        }
    }

    // Record center
    if gs.n_centers < 16 {
        gs.centers[gs.n_centers] = cast(u16)(cx + cy * 256);
        gs.n_centers += 1;
    }

    // Track room
    room: Room;
    room.bounds = r;
    room.connected = false;
    array_add(*m.rooms, room);
}

// Write an octagonal room
// In original: void Map::WriteOctagon(Rect &r, rID regID)
write_octagon :: (m: *GenMap, gs: *GenState, r: Rect) {
    // Start with rectangular room (uses region terrain)
    write_room(m, gs, r);

    wall := gs.con.TERRAIN_WALL;
    wall_terrain := get_region_wall(gs.current_region, gs.default_wall);

    // Cut corners
    corner_size := min(rect_width(r), rect_height(r)) / 4;
    if corner_size < 1 corner_size = 1;

    // Top-left
    for i: 0..corner_size-1 {
        for j: 0..corner_size-1-i {
            write_at_with_terrain(m, gs, r.x1 + j, r.y1 + i, wall, wall_terrain, PRIO_ROOM_WALL);
        }
    }
    // Top-right
    for i: 0..corner_size-1 {
        for j: 0..corner_size-1-i {
            write_at_with_terrain(m, gs, r.x2 - j, r.y1 + i, wall, wall_terrain, PRIO_ROOM_WALL);
        }
    }
    // Bottom-left
    for i: 0..corner_size-1 {
        for j: 0..corner_size-1-i {
            write_at_with_terrain(m, gs, r.x1 + j, r.y2 - i, wall, wall_terrain, PRIO_ROOM_WALL);
        }
    }
    // Bottom-right
    for i: 0..corner_size-1 {
        for j: 0..corner_size-1-i {
            write_at_with_terrain(m, gs, r.x2 - j, r.y2 - i, wall, wall_terrain, PRIO_ROOM_WALL);
        }
    }
}

// Write a cross-shaped room
// In original: void Map::WriteCross(Rect &r, rID regID)
write_cross :: (m: *GenMap, gs: *GenState, r: Rect) {
    cx, cy := rect_center(r);
    w := rect_width(r);
    h := rect_height(r);

    // Horizontal bar (uses region terrain via write_room)
    bar_h := max(h / 3, 3);
    h_rect := Rect.{r.x1, cy - bar_h/2, r.x2, cy + bar_h/2};
    write_room(m, gs, h_rect);

    // Vertical bar
    bar_w := max(w / 3, 3);
    v_rect := Rect.{cx - bar_w/2, r.y1, cx + bar_w/2, r.y2};

    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;
    floor_terrain := get_region_floor(gs.current_region, gs.default_floor);
    wall_terrain := get_region_wall(gs.current_region, gs.default_wall);

    // Fill vertical bar
    for y: v_rect.y1..v_rect.y2 {
        for x: v_rect.x1..v_rect.x2 {
            write_at_with_terrain(m, gs, x, y, floor, floor_terrain, PRIO_ROOM_FLOOR);
        }
    }

    // Add walls around vertical bar
    for y: v_rect.y1-1..v_rect.y2+1 {
        if map_get(m, v_rect.x1-1, y) == .ROCK  write_at_with_terrain(m, gs, v_rect.x1-1, y, wall, wall_terrain, PRIO_ROOM_WALL);
        if map_get(m, v_rect.x2+1, y) == .ROCK  write_at_with_terrain(m, gs, v_rect.x2+1, y, wall, wall_terrain, PRIO_ROOM_WALL);
    }
    for x: v_rect.x1..v_rect.x2 {
        if map_get(m, x, v_rect.y1-1) == .ROCK  write_at_with_terrain(m, gs, x, v_rect.y1-1, wall, wall_terrain, PRIO_ROOM_WALL);
        if map_get(m, x, v_rect.y2+1) == .ROCK  write_at_with_terrain(m, gs, x, v_rect.y2+1, wall, wall_terrain, PRIO_ROOM_WALL);
    }
}

// Write a cave using cellular automata (Game of Life variant)
// In original: void Map::WriteLifeCave(Rect &r, rID regID)
write_lifecave :: (m: *GenMap, gs: *GenState, r: Rect) {
    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;
    floor_terrain := get_region_floor(gs.current_region, gs.default_floor);
    wall_terrain := get_region_wall(gs.current_region, gs.default_wall);

    LIFE_PERCENT :: 45;  // Initial rock probability
    BUFFER :: 3;         // Border buffer (always rock)
    ITERATIONS :: 20;    // Number of automata iterations

    // Temporary grid for cellular automata
    // Uses a simple 2D array - 1 = wall, 0 = open
    w := rect_width(r) + 2;
    h := rect_height(r) + 2;

    // Allocate grids
    grid: [..] u8;
    grid.allocator = temp;
    array_resize(*grid, w * h);

    next_grid: [..] u8;
    next_grid.allocator = temp;
    array_resize(*next_grid, w * h);

    // Initialize: edges are walls, interior is random
    for gy: 0..h-1 {
        for gx: 0..w-1 {
            idx := gy * w + gx;
            // Buffer zone is always wall
            if gx < BUFFER || gx >= w - BUFFER || gy < BUFFER || gy >= h - BUFFER {
                grid[idx] = 1;
            } else {
                grid[idx] = cast(u8) ifx random(100) < LIFE_PERCENT then 1 else 0;
            }
        }
    }

    // Run cellular automata iterations
    for iter: 0..ITERATIONS-1 {
        for gy: BUFFER..h-BUFFER-1 {
            for gx: BUFFER..w-BUFFER-1 {
                idx := gy * w + gx;

                // Count wall neighbors (8-connected)
                neighbors: s32 = 0;
                for dy: -1..1 {
                    for dx: -1..1 {
                        if dx == 0 && dy == 0 continue;
                        nidx := (gy + cast(s32)dy) * w + (gx + cast(s32)dx);
                        if grid[nidx] == 1 neighbors += 1;
                    }
                }

                // Apply rules: 5+ neighbors = wall, 3 or fewer = open
                if neighbors >= 5 {
                    next_grid[idx] = 1;
                } else if neighbors <= 3 {
                    next_grid[idx] = 0;
                } else {
                    next_grid[idx] = grid[idx];  // Stay same
                }
            }
        }

        // Copy next_grid to grid for next iteration
        for i: 0..grid.count-1 {
            grid[i] = next_grid[i];
        }
    }

    // Write result to map
    for gy: 0..h-1 {
        for gx: 0..w-1 {
            idx := gy * w + gx;
            mx := r.x1 + cast(s32)gx - 1;
            my := r.y1 + cast(s32)gy - 1;

            if grid[idx] == 0 {
                write_at_with_terrain(m, gs, mx, my, floor, floor_terrain, PRIO_ROOM_FLOOR);
            }
        }
    }

    // Add walls around open spaces (use full bounds to catch edge tiles)
    for gy: 0..h-1 {
        for gx: 0..w-1 {
            idx := gy * w + gx;
            if grid[idx] == 0 {  // This is floor
                mx := r.x1 + cast(s32)gx - 1;
                my := r.y1 + cast(s32)gy - 1;
                // Check all 8 neighbors for rock
                for dy: -1..1 {
                    for dx: -1..1 {
                        if dx == 0 && dy == 0 continue;
                        if map_get(m, mx + cast(s32)dx, my + cast(s32)dy) == .ROCK {
                            write_at_with_terrain(m, gs, mx + cast(s32)dx, my + cast(s32)dy, wall, wall_terrain, PRIO_ROOM_WALL);
                        }
                    }
                }
            }
        }
    }

    // Track as a room (use the full rect bounds)
    room: Room;
    room.bounds = r;
    room.connected = false;
    array_add(*m.rooms, room);

    // Record center
    if gs.n_centers < 16 {
        cx, cy := rect_center(r);
        gs.centers[gs.n_centers] = cast(u16)(cx + cy * 256);
        gs.n_centers += 1;
    }
}

// Write overlapping rectangles (2-4 random boxes)
// In original: case RM_OVERLAP in DrawPanel
write_overlap :: (m: *GenMap, gs: *GenState, panel: Rect) {
    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;
    floor_terrain := get_region_floor(gs.current_region, gs.default_floor);
    wall_terrain := get_region_wall(gs.current_region, gs.default_wall);

    // Draw 2-4 overlapping rectangles
    num_boxes := 2 + random(3);  // 2, 3, or 4 boxes

    for i: 0..num_boxes-1 {
        // Random size for each box (smaller than normal rooms)
        box_w := 3 + random(6);  // 3-8
        box_h := 3 + random(5);  // 3-7

        // Random position within panel
        panel_w := rect_width(panel);
        panel_h := rect_height(panel);

        x1 := panel.x1 + 2 + random(cast(s32)max(1, panel_w - box_w - 4));
        y1 := panel.y1 + 2 + random(cast(s32)max(1, panel_h - box_h - 4));

        r := Rect.{x1, y1, x1 + box_w - 1, y1 + box_h - 1};

        // Fill with floor
        for y: r.y1..r.y2 {
            for x: r.x1..r.x2 {
                write_at_with_terrain(m, gs, x, y, floor, floor_terrain, PRIO_ROOM_FLOOR);
            }
        }
    }

    // Add walls around all floor tiles
    for y: panel.y1..panel.y2 {
        for x: panel.x1..panel.x2 {
            if map_get(m, x, y) == floor {
                // Check neighbors for rock and add walls
                for dy: -1..1 {
                    for dx: -1..1 {
                        if dx == 0 && dy == 0 continue;
                        nx := x + cast(s32)dx;
                        ny := y + cast(s32)dy;
                        if map_get(m, nx, ny) == .ROCK {
                            write_at_with_terrain(m, gs, nx, ny, wall, wall_terrain, PRIO_ROOM_WALL);
                        }
                    }
                }
            }
        }
    }

    // Track as room
    room: Room;
    room.bounds = panel;
    room.connected = false;
    array_add(*m.rooms, room);

    // Record center
    if gs.n_centers < 16 {
        cx, cy := rect_center(panel);
        gs.centers[gs.n_centers] = cast(u16)(cx + cy * 256);
        gs.n_centers += 1;
    }
}

// Write adjacent four-quadrant room
// In original: case RM_ADJACENT/RM_AD_ROUND/RM_AD_MIXED
// Four boxes with a shared center-point compose a single room
write_adjacent :: (m: *GenMap, gs: *GenState, panel: Rect, use_circles: bool = false, mixed: bool = false) {
    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;

    panel_w := gs.con.PANEL_SIZEX;
    panel_h := gs.con.PANEL_SIZEY;

    // Shared center point
    center_x := panel.x1 + panel_w / 2;
    center_y := panel.y1 + panel_h / 2;

    // Four quadrant rects sharing center
    // Top-left (r1)
    r1 := Rect.{
        panel.x1 + 2 + random(panel_w / 4),
        panel.y1 + 2 + random(panel_h / 4),
        center_x,
        center_y
    };

    // Top-right (r2)
    r2 := Rect.{
        center_x,
        panel.y1 + 2 + random(panel_h / 4),
        panel.x2 - 2 - random(panel_w / 4),
        center_y
    };

    // Bottom-left (r3)
    r3 := Rect.{
        panel.x1 + 2 + random(panel_w / 4),
        center_y,
        center_x,
        panel.y2 - 2 - random(panel_h / 4)
    };

    // Bottom-right (r4)
    r4 := Rect.{
        center_x,
        center_y,
        panel.x2 - 2 - random(panel_w / 4),
        panel.y2 - 2 - random(panel_h / 4)
    };

    // Draw each quadrant (at least one must be drawn)
    drawn_any := false;
    while !drawn_any {
        if random(4) != 0 {
            drawn_any = true;
            if use_circles || (mixed && random(2) == 0) {
                write_circle(m, gs, r1);
            } else {
                write_box(m, gs, r1);
            }
        }

        if random(4) != 0 {
            drawn_any = true;
            if use_circles || (mixed && random(2) == 0) {
                write_circle(m, gs, r2);
            } else {
                write_box(m, gs, r2);
            }
        }

        if random(4) != 0 {
            drawn_any = true;
            if use_circles || (mixed && random(2) == 0) {
                write_circle(m, gs, r3);
            } else {
                write_box(m, gs, r3);
            }
        }

        if random(4) != 0 {
            drawn_any = true;
            if use_circles || (mixed && random(2) == 0) {
                write_circle(m, gs, r4);
            } else {
                write_box(m, gs, r4);
            }
        }
    }

    // Add walls around the whole panel
    write_walls(m, gs, panel);
}

// Write a simple box (floor only, no walls)
// Helper for write_adjacent
write_box :: (m: *GenMap, gs: *GenState, r: Rect) {
    floor := gs.con.TERRAIN_FLOOR;
    floor_terrain := get_region_floor(gs.current_region, gs.default_floor);

    for y: r.y1..r.y2 {
        for x: r.x1..r.x2 {
            write_at_with_terrain(m, gs, x, y, floor, floor_terrain, PRIO_ROOM_FLOOR);
        }
    }

    // Record center
    if gs.n_centers < 16 {
        cx, cy := rect_center(r);
        gs.centers[gs.n_centers] = cast(u16)(cx + cy * 256);
        gs.n_centers += 1;
    }
}

// Write walls around floor tiles in a rect
write_walls :: (m: *GenMap, gs: *GenState, r: Rect) {
    wall := gs.con.TERRAIN_WALL;
    floor := gs.con.TERRAIN_FLOOR;
    wall_terrain := get_region_wall(gs.current_region, gs.default_wall);

    for y: r.y1..r.y2 {
        for x: r.x1..r.x2 {
            if map_get(m, x, y) == floor {
                // Check all 8 neighbors
                for dy: -1..1 {
                    for dx: -1..1 {
                        if dx == 0 && dy == 0 continue;
                        nx := x + cast(s32)dx;
                        ny := y + cast(s32)dy;
                        if map_get(m, nx, ny) == .ROCK {
                            write_at_with_terrain(m, gs, nx, ny, wall, wall_terrain, PRIO_ROOM_WALL);
                        }
                    }
                }
            }
        }
    }

    // Track as room
    room: Room;
    room.bounds = r;
    room.connected = false;
    array_add(*m.rooms, room);
}

// Write a room with pillars
// In original: case RM_PILLARS
write_pillars :: (m: *GenMap, gs: *GenState, r: Rect) {
    // First create normal room (uses region terrain)
    write_room(m, gs, r);

    wall := gs.con.TERRAIN_WALL;
    wall_terrain := get_region_wall(gs.current_region, gs.default_wall);

    // Add pillars in a grid pattern (every 2 tiles)
    for y: r.y1+1..r.y2-1 {
        for x: r.x1+1..r.x2-1 {
            // Place pillar at even intervals from top-left
            x_offset := x - r.x1;
            y_offset := y - r.y1;
            if (x_offset % 2 == 0) && (y_offset % 2 == 0) {
                // 95% chance of pillar (5% missing for variety)
                if random(100) < 95 {
                    write_at_with_terrain(m, gs, x, y, wall, wall_terrain, PRIO_ROOM_FURNITURE);
                }
            }
        }
    }
}

// Write a double room (room within a room)
// In original: case RM_DOUBLE
write_double :: (m: *GenMap, gs: *GenState, r: Rect) {
    // Outer room (uses region terrain)
    write_room(m, gs, r);

    wall := gs.con.TERRAIN_WALL;
    floor := gs.con.TERRAIN_FLOOR;
    wall_terrain := get_region_wall(gs.current_region, gs.default_wall);
    floor_terrain := get_region_floor(gs.current_region, gs.default_floor);

    // Inner room (inset by 2)
    inner := Rect.{r.x1 + 2, r.y1 + 2, r.x2 - 2, r.y2 - 2};

    // Make sure inner room is big enough
    if rect_width(inner) < 3 || rect_height(inner) < 3 return;

    // Draw inner walls
    for x: inner.x1..inner.x2 {
        write_at_with_terrain(m, gs, x, inner.y1, wall, wall_terrain, PRIO_ROOM_FURNITURE);
        write_at_with_terrain(m, gs, x, inner.y2, wall, wall_terrain, PRIO_ROOM_FURNITURE);
    }
    for y: inner.y1..inner.y2 {
        write_at_with_terrain(m, gs, inner.x1, y, wall, wall_terrain, PRIO_ROOM_FURNITURE);
        write_at_with_terrain(m, gs, inner.x2, y, wall, wall_terrain, PRIO_ROOM_FURNITURE);
    }

    // Add 1-3 doors in the inner wall
    num_doors := 1 + random(3);
    for i: 0..num_doors-1 {
        if random(2) == 0 {
            // Door on horizontal wall
            x := inner.x1 + 1 + random(rect_width(inner) - 2);
            y := ifx random(2) == 0 then inner.y1 else inner.y2;
            write_at_with_terrain(m, gs, x, cast(s32)y, floor, floor_terrain, PRIO_ROOM_FURNITURE);
        } else {
            // Door on vertical wall
            x := ifx random(2) == 0 then inner.x1 else inner.x2;
            y := inner.y1 + 1 + random(rect_height(inner) - 2);
            write_at_with_terrain(m, gs, cast(s32)x, y, floor, floor_terrain, PRIO_ROOM_FURNITURE);
        }
    }
}

// Write a maze room using recursive backtracking
// In original: case RM_MAZE (calls WriteMaze)
write_maze :: (m: *GenMap, gs: *GenState, r: Rect) {
    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;
    floor_terrain := get_region_floor(gs.current_region, gs.default_floor);
    wall_terrain := get_region_wall(gs.current_region, gs.default_wall);

    // First fill with walls
    for y: r.y1..r.y2 {
        for x: r.x1..r.x2 {
            write_at_with_terrain(m, gs, x, y, wall, wall_terrain, PRIO_ROOM_WALL);
        }
    }

    // Use a simple recursive backtracker maze algorithm
    // Start from a random odd position
    maze_w := rect_width(r);
    maze_h := rect_height(r);

    // Ensure odd dimensions for proper maze
    start_x := r.x1 + 1;
    start_y := r.y1 + 1;

    // Stack for backtracking (use temp allocator)
    stack: [..] struct { x: s32; y: s32; };
    stack.allocator = temp;

    // Visited grid
    visited: [..] bool;
    visited.allocator = temp;
    array_resize(*visited, maze_w * maze_h);

    // Mark start as visited and carve
    idx := (start_y - r.y1) * maze_w + (start_x - r.x1);
    visited[idx] = true;
    write_at_with_terrain(m, gs, start_x, start_y, floor, floor_terrain, PRIO_ROOM_FLOOR);
    array_add(*stack, .{start_x, start_y});

    // Maze directions (2 steps to leave wall between cells)
    DIRS :: s32.[
        0, -2,   // North
        2, 0,    // East
        0, 2,    // South
        -2, 0    // West
    ];

    while stack.count > 0 {
        current := stack[stack.count - 1];
        cx := current.x;
        cy := current.y;

        // Find unvisited neighbors
        unvisited: [..] s32;
        unvisited.allocator = temp;

        for dir: 0..3 {
            nx := cx + DIRS[dir * 2];
            ny := cy + DIRS[dir * 2 + 1];

            // Check bounds
            if nx < r.x1 + 1 || nx > r.x2 - 1 continue;
            if ny < r.y1 + 1 || ny > r.y2 - 1 continue;

            // Check if visited
            nidx := (ny - r.y1) * maze_w + (nx - r.x1);
            if !visited[nidx] {
                array_add(*unvisited, cast(s32)dir);
            }
        }

        if unvisited.count > 0 {
            // Choose random unvisited neighbor
            dir := unvisited[random(cast(s32)unvisited.count)];
            nx := cx + DIRS[dir * 2];
            ny := cy + DIRS[dir * 2 + 1];

            // Carve path to neighbor (including wall between)
            wall_x := cx + DIRS[dir * 2] / 2;
            wall_y := cy + DIRS[dir * 2 + 1] / 2;
            write_at_with_terrain(m, gs, wall_x, wall_y, floor, floor_terrain, PRIO_ROOM_FLOOR);
            write_at_with_terrain(m, gs, nx, ny, floor, floor_terrain, PRIO_ROOM_FLOOR);

            // Mark as visited and push to stack
            nidx := (ny - r.y1) * maze_w + (nx - r.x1);
            visited[nidx] = true;
            array_add(*stack, .{nx, ny});
        } else {
            // Backtrack
            pop(*stack);
        }
    }

    // Track as room
    room: Room;
    room.bounds = r;
    room.connected = false;
    array_add(*m.rooms, room);

    // Record center
    if gs.n_centers < 16 {
        cx, cy := rect_center(r);
        gs.centers[gs.n_centers] = cast(u16)(cx + cy * 256);
        gs.n_centers += 1;
    }
}

// Write a checkerboard pattern room
// In original: case RM_CHECKER
write_checker :: (m: *GenMap, gs: *GenState, r: Rect) {
    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;
    floor_terrain := get_region_floor(gs.current_region, gs.default_floor);
    wall_terrain := get_region_wall(gs.current_region, gs.default_wall);

    // Fill with floor first
    for y: r.y1..r.y2 {
        for x: r.x1..r.x2 {
            write_at_with_terrain(m, gs, x, y, floor, floor_terrain, PRIO_ROOM_FLOOR);
        }
    }

    // Add checkerboard walls (every 2nd cell)
    for y: r.y1+1..r.y2-1 {
        for x: r.x1+1..r.x2-1 {
            x_even := ((x - r.x1) % 2) == 0;
            y_even := ((y - r.y1) % 2) == 0;
            if x_even == y_even {
                write_at_with_terrain(m, gs, x, y, wall, wall_terrain, PRIO_ROOM_FURNITURE);
            }
        }
    }

    // Add walls around the perimeter
    for x: r.x1-1..r.x2+1 {
        if map_get(m, x, r.y1-1) == .ROCK  write_at_with_terrain(m, gs, x, r.y1-1, wall, wall_terrain, PRIO_ROOM_WALL);
        if map_get(m, x, r.y2+1) == .ROCK  write_at_with_terrain(m, gs, x, r.y2+1, wall, wall_terrain, PRIO_ROOM_WALL);
    }
    for y: r.y1-1..r.y2+1 {
        if map_get(m, r.x1-1, y) == .ROCK  write_at_with_terrain(m, gs, r.x1-1, y, wall, wall_terrain, PRIO_ROOM_WALL);
        if map_get(m, r.x2+1, y) == .ROCK  write_at_with_terrain(m, gs, r.x2+1, y, wall, wall_terrain, PRIO_ROOM_WALL);
    }

    // Track as room
    room: Room;
    room.bounds = r;
    room.connected = false;
    array_add(*m.rooms, room);

    // Record center
    if gs.n_centers < 16 {
        cx, cy := rect_center(r);
        gs.centers[gs.n_centers] = cast(u16)(cx + cy * 256);
        gs.n_centers += 1;
    }
}

// Write a single filled diamond shape (41 cells, radius 4)
// In original: void Map::WriteDiamond(int16 x, int16 y, rID regID)
// at MakeLev.cpp:664-685
write_diamond :: (m: *GenMap, gs: *GenState, cx: s32, cy: s32) {
    floor := gs.con.TERRAIN_FLOOR;
    floor_terrain := get_region_floor(gs.current_region, gs.default_floor);

    // 41-entry coordinate table for filled diamond with radius 4
    // Original: DiamondCoords[41][2] in MakeLev.cpp:665-675
    DIAMOND_COORDS :: s32.[
        0, -4,
        -1, -3,  0, -3,  1, -3,
        -2, -2, -1, -2,  0, -2,  1, -2,  2, -2,
        -3, -1, -2, -1, -1, -1,  0, -1,  1, -1,  2, -1,  3, -1,
        -4,  0, -3,  0, -2,  0, -1,  0,  0,  0,  1,  0,  2,  0,  3,  0,  4,  0,
        -3,  1, -2,  1, -1,  1,  0,  1,  1,  1,  2,  1,  3,  1,
        -2,  2, -1,  2,  0,  2,  1,  2,  2,  2,
        -1,  3,  0,  3,  1,  3,
         0,  4,
    ];

    i := 0;
    while i < DIAMOND_COORDS.count {
        dx := DIAMOND_COORDS[i];
        dy := DIAMOND_COORDS[i + 1];
        write_at_with_terrain(m, gs, cx + dx, cy + dy, floor, floor_terrain, PRIO_ROOM_FLOOR);
        i += 2;
    }

    // Record center for corridor connection
    if gs.n_centers < 16 {
        gs.centers[gs.n_centers] = cast(u16)(cx + cy * 256);
        gs.n_centers += 1;
    }
}

// Write a chain of diamond-shaped rooms with doors between them
// In original: case RM_DIAMONDS at MakeLev.cpp:2640-2677
// Algorithm: 1-7 filled diamonds in chain formation, 6 cells apart in diagonal
// directions, with doors at midpoints between each pair.
write_diamonds :: (m: *GenMap, gs: *GenState, panel: Rect) {
    floor := gs.con.TERRAIN_FLOOR;
    floor_terrain := get_region_floor(gs.current_region, gs.default_floor);

    // Bounds: panel inset by 7 on each side (per original)
    r := Rect.{panel.x1 + 7, panel.y1 + 7, panel.x2 - 7, panel.y2 - 7};
    if r.x2 <= r.x1 || r.y2 <= r.y1 {
        // Panel too small, fall back to regular room
        write_room(m, gs, panel);
        return;
    }

    // Start at random point within bounds
    x : s32 = r.x1 + random(r.x2 - r.x1);
    y : s32 = r.y1 + random(r.y2 - r.y1);

    num_diamonds : s32 = 1 + random(7);  // 1-7 diamonds
    count : s32 = 0;

    // Door junction tracking (for corridor connection marking)
    door_x: [8] s32;
    door_y: [8] s32;
    door_count : s32 = 0;

    while count < num_diamonds {
        write_diamond(m, gs, x, y);
        count += 1;

        if count >= num_diamonds break;

        // Pick random diagonal direction that stays in bounds
        // Original: NORTHEAST + random(4) => one of NE, NW, SE, SW
        DIAG_DIRS :: Dir.[.NORTHEAST, .NORTHWEST, .SOUTHEAST, .SOUTHWEST];
        dir : Dir = ---;
        tries : s32 = 0;
        valid := false;
        while tries < 20 {
            dir = DIAG_DIRS[random(4)];
            nx := x + cast(s32)DirX(dir) * 6;
            ny := y + cast(s32)DirY(dir) * 6;
            if rect_contains(r, nx, ny) {
                valid = true;
                break;
            }
            tries += 1;
        }
        if !valid break;  // Can't find valid direction, stop chain

        // Move 6 cells in chosen diagonal
        x += cast(s32)DirX(dir) * 6;
        y += cast(s32)DirY(dir) * 6;

        // Place floor + door at midpoint between diamonds
        mx := x - cast(s32)DirX(dir) * 3;
        my := y - cast(s32)DirY(dir) * 3;

        write_at_with_terrain(m, gs, mx, my, floor, floor_terrain, PRIO_ROOM_FLOOR, force = true);
        map_set(m, mx, my, .DOOR_CLOSED);

        if door_count < 8 {
            door_x[door_count] = mx;
            door_y[door_count] = my;
            door_count += 1;
        }
    }

    // Add walls around all floor tiles (equivalent to WriteWalls in original)
    write_walls(m, gs, panel);

    // Track as room
    room: Room;
    room.bounds = panel;
    room.connected = false;
    array_add(*m.rooms, room);
}

// Write a castle room (recursively subdivided with internal walls and doors)
// In original: void Map::WriteCastle(Rect &r, rID regID)
write_castle :: (m: *GenMap, gs: *GenState, r: Rect, depth: s32 = 0) {
    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;
    floor_terrain := get_region_floor(gs.current_region, gs.default_floor);
    wall_terrain := get_region_wall(gs.current_region, gs.default_wall);

    sx := rect_width(r);
    sy := rect_height(r);

    // Base case: too small to subdivide further
    if sx < 7 || sy < 7 || depth > 4 {
        // Just fill with floor
        for y: r.y1..r.y2 {
            for x: r.x1..r.x2 {
                write_at_with_terrain(m, gs, x, y, floor, floor_terrain, PRIO_ROOM_FLOOR);
            }
        }
        return;
    }

    // Fill base with floor first
    for y: r.y1..r.y2 {
        for x: r.x1..r.x2 {
            write_at_with_terrain(m, gs, x, y, floor, floor_terrain, PRIO_ROOM_FLOOR);
        }
    }

    // Decide split direction (prefer splitting longer dimension, with some randomness)
    split_vertical := (sx > sy && random(9) != 0) || random(10) == 0;

    if split_vertical {
        // Vertical split - find split position
        d := r.x1 + 2 + random(sx - 4);

        // Find door position
        door_y := r.y1 + 1 + random(sy - 2);

        // Draw vertical wall with door
        for y: r.y1..r.y2 {
            if y != door_y {
                write_at_with_terrain(m, gs, d, y, wall, wall_terrain, PRIO_ROOM_FURNITURE);
            }
        }

        // Recurse on both halves
        r1 := Rect.{r.x1, r.y1, d - 1, r.y2};
        r2 := Rect.{d + 1, r.y1, r.x2, r.y2};
        write_castle(m, gs, r1, depth + 1);
        write_castle(m, gs, r2, depth + 1);
    } else {
        // Horizontal split
        d := r.y1 + 2 + random(sy - 4);

        // Find door position
        door_x := r.x1 + 1 + random(sx - 2);

        // Draw horizontal wall with door
        for x: r.x1..r.x2 {
            if x != door_x {
                write_at_with_terrain(m, gs, x, d, wall, wall_terrain, PRIO_ROOM_FURNITURE);
            }
        }

        // Recurse on both halves
        r1 := Rect.{r.x1, r.y1, r.x2, d - 1};
        r2 := Rect.{r.x1, d + 1, r.x2, r.y2};
        write_castle(m, gs, r1, depth + 1);
        write_castle(m, gs, r2, depth + 1);
    }

    // Only track as room at top level
    if depth == 0 {
        // Add outer walls
        for x: r.x1-1..r.x2+1 {
            if map_get(m, x, r.y1-1) == .ROCK  write_at_with_terrain(m, gs, x, r.y1-1, wall, wall_terrain, PRIO_ROOM_WALL);
            if map_get(m, x, r.y2+1) == .ROCK  write_at_with_terrain(m, gs, x, r.y2+1, wall, wall_terrain, PRIO_ROOM_WALL);
        }
        for y: r.y1-1..r.y2+1 {
            if map_get(m, r.x1-1, y) == .ROCK  write_at_with_terrain(m, gs, r.x1-1, y, wall, wall_terrain, PRIO_ROOM_WALL);
            if map_get(m, r.x2+1, y) == .ROCK  write_at_with_terrain(m, gs, r.x2+1, y, wall, wall_terrain, PRIO_ROOM_WALL);
        }

        // Track as room
        room: Room;
        room.bounds = r;
        room.connected = false;
        array_add(*m.rooms, room);

        // Record center
        if gs.n_centers < 16 {
            cx, cy := rect_center(r);
            gs.centers[gs.n_centers] = cast(u16)(cx + cy * 256);
            gs.n_centers += 1;
        }
    }
}

// Write a rough cavern using repeated L-shapes
// In original: void Map::WriteRCavern(Rect &r, rID regID)
write_rcavern :: (m: *GenMap, gs: *GenState, r: Rect) {
    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;
    floor_terrain := get_region_floor(gs.current_region, gs.default_floor);
    wall_terrain := get_region_wall(gs.current_region, gs.default_wall);

    BUFFER :: 3;
    sx := rect_width(r) - BUFFER;
    sy := rect_height(r) - BUFFER;

    if sx < 12 || sy < 12 {
        // Too small, just make a regular room (uses region terrain)
        write_room(m, gs, r);
        return;
    }

    // Number of L-shapes to draw (proportional to area)
    num_shapes := (sx * sy) / 20;

    for i: 0..num_shapes-1 {
        // Random center point within buffer
        x := BUFFER + r.x1 + 5 + random(sx - 10);
        y := BUFFER + r.y1 + 5 + random(sy - 10);

        // Draw an L-shape (5 tiles in each direction)
        L_LEN :: 5;
        direction := random(4);

        if direction == 0 {
            // Right and up
            for j: 0..L_LEN-1 {
                write_at_with_terrain(m, gs, x + cast(s32)j, y, floor, floor_terrain, PRIO_ROOM_FLOOR);
                write_at_with_terrain(m, gs, x, y - cast(s32)j, floor, floor_terrain, PRIO_ROOM_FLOOR);
            }
        } else if direction == 1 {
            // Right and down
            for j: 0..L_LEN-1 {
                write_at_with_terrain(m, gs, x + cast(s32)j, y, floor, floor_terrain, PRIO_ROOM_FLOOR);
                write_at_with_terrain(m, gs, x, y + cast(s32)j, floor, floor_terrain, PRIO_ROOM_FLOOR);
            }
        } else if direction == 2 {
            // Left and up
            for j: 0..L_LEN-1 {
                write_at_with_terrain(m, gs, x - cast(s32)j, y, floor, floor_terrain, PRIO_ROOM_FLOOR);
                write_at_with_terrain(m, gs, x, y - cast(s32)j, floor, floor_terrain, PRIO_ROOM_FLOOR);
            }
        } else {
            // Left and down
            for j: 0..L_LEN-1 {
                write_at_with_terrain(m, gs, x - cast(s32)j, y, floor, floor_terrain, PRIO_ROOM_FLOOR);
                write_at_with_terrain(m, gs, x, y + cast(s32)j, floor, floor_terrain, PRIO_ROOM_FLOOR);
            }
        }
    }

    // Add walls around all floor tiles
    for y: r.y1..r.y2 {
        for x: r.x1..r.x2 {
            if map_get(m, x, y) == floor {
                // Check all 8 neighbors
                for dy: -1..1 {
                    for dx: -1..1 {
                        if dx == 0 && dy == 0 continue;
                        nx := x + cast(s32)dx;
                        ny := y + cast(s32)dy;
                        if map_get(m, nx, ny) == .ROCK {
                            write_at_with_terrain(m, gs, nx, ny, wall, wall_terrain, PRIO_ROOM_WALL);
                        }
                    }
                }
            }
        }
    }

    // Wall streamer pass: if region has custom walls, theme surrounding rock
    // Original: MakeLev.cpp:590-599 — converts default rock adjacent to floor
    // into region wall type at PRIO_ROCK_STREAMER for visual theming
    if wall_terrain != null && wall_terrain != gs.default_wall {
        for y: r.y1..r.y2 {
            for x: r.x1..r.x2 {
                if map_get(m, x, y) != .ROCK continue;
                // Check all 9 positions (including self) for adjacent floor
                found_floor := false;
                for dy: -1..1 {
                    for dx: -1..1 {
                        nx := x + cast(s32)dx;
                        ny := y + cast(s32)dy;
                        if map_in_bounds(m, nx, ny) && map_get(m, nx, ny) == floor {
                            found_floor = true;
                            break dy;
                        }
                    }
                }
                if found_floor {
                    write_at_with_terrain(m, gs, x, y, wall, wall_terrain, PRIO_ROCK_STREAMER);
                }
            }
        }
    }

    // Track as room
    room: Room;
    room.bounds = r;
    room.connected = false;
    array_add(*m.rooms, room);

    // Record center
    if gs.n_centers < 16 {
        cx, cy := rect_center(r);
        gs.centers[gs.n_centers] = cast(u16)(cx + cy * 256);
        gs.n_centers += 1;
    }
}

// Write a destroyed/collapsed room
// In original: case RM_DESTROYED in DrawPanel
// Per spec: 10% rock, 30% rubble (wall), rest floor - creates ruined appearance
write_destroyed :: (m: *GenMap, gs: *GenState, r: Rect) {
    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;
    floor_terrain := get_region_floor(gs.current_region, gs.default_floor);
    wall_terrain := get_region_wall(gs.current_region, gs.default_wall);

    // Fill the area with random terrain
    // 10% rock (unchanged), 30% rubble (wall at lower priority), 60% floor
    for y: r.y1..r.y2 {
        for x: r.x1..r.x2 {
            roll := random(100);
            if roll < 10 {
                // 10% - leave as rock (don't write anything)
                continue;
            } else if roll < 40 {
                // 30% - rubble (walls at lower priority)
                write_at_with_terrain(m, gs, x, y, wall, wall_terrain, PRIO_ROCK_STREAMER);
            } else {
                // 60% - floor
                write_at_with_terrain(m, gs, x, y, floor, floor_terrain, PRIO_ROOM_FLOOR);
            }
        }
    }

    // Add walls around floor tiles for better definition
    for y: r.y1..r.y2 {
        for x: r.x1..r.x2 {
            if map_get(m, x, y) == floor {
                for dy: -1..1 {
                    for dx: -1..1 {
                        if dx == 0 && dy == 0 continue;
                        nx := x + cast(s32)dx;
                        ny := y + cast(s32)dy;
                        if map_get(m, nx, ny) == .ROCK {
                            write_at_with_terrain(m, gs, nx, ny, wall, wall_terrain, PRIO_ROOM_WALL);
                        }
                    }
                }
            }
        }
    }

    // Track as room
    room: Room;
    room.bounds = r;
    room.connected = false;
    array_add(*m.rooms, room);

    if gs.n_centers < 16 {
        cx, cy := rect_center(r);
        gs.centers[gs.n_centers] = cast(u16)(cx + cy * 256);
        gs.n_centers += 1;
    }
}

// Write a room with furnishing grid
// In original: case RM_GRID in DrawPanel
// Per spec: uses region's Furnishings[0] (we use pillars) in 2x2 pattern, 5% chance each missing
write_grid :: (m: *GenMap, gs: *GenState, r: Rect) {
    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;
    floor_terrain := get_region_floor(gs.current_region, gs.default_floor);
    wall_terrain := get_region_wall(gs.current_region, gs.default_wall);

    // First create the room with walls (uses region terrain)
    write_room(m, gs, r);

    // Add furnishing grid (pillars every 2 tiles, with 5% chance of missing)
    for y: r.y1+2..r.y2-1 {
        for x: r.x1+2..r.x2-1 {
            // Check if this is a grid position (every 2 tiles)
            if (x - r.x1) % 2 == 0 && (y - r.y1) % 2 == 0 {
                // 95% chance to place furnishing
                if random(100) >= 5 {
                    write_at_with_terrain(m, gs, x, y, wall, wall_terrain, PRIO_ROOM_FURNITURE);
                }
            }
        }
    }
}

// Draw a single building within a town grid cell
// Draws wall perimeter at PRIO_ROOM_FURNITURE (75) to overwrite street floor (70),
// with random size shrinkage for variety (min 3x3) and one door on a random side.
write_town_building :: (m: *GenMap, gs: *GenState, cell: Rect, wall_terrain: *RuntimeTerrain, floor_terrain: *RuntimeTerrain) {
    wall := gs.con.TERRAIN_WALL;
    floor := gs.con.TERRAIN_FLOOR;

    // Optionally shrink the building within the cell for variety (min 3x3 interior)
    cw := rect_width(cell);
    ch := rect_height(cell);
    shrink_x : s32 = 0;
    shrink_y : s32 = 0;
    if cw > 4  shrink_x = random(min(cw - 4, 2));
    if ch > 4  shrink_y = random(min(ch - 4, 2));

    bx1 : s32 = cell.x1 + shrink_x;
    by1 : s32 = cell.y1 + shrink_y;
    bx2 : s32 = cell.x2 - (shrink_x / 2);
    by2 : s32 = cell.y2 - (shrink_y / 2);

    // Need at least 3x3 for a building
    if (bx2 - bx1) < 2 || (by2 - by1) < 2  return;

    // Draw wall perimeter
    for x: bx1..bx2 {
        write_at_with_terrain(m, gs, x, by1, wall, wall_terrain, PRIO_ROOM_FURNITURE);
        write_at_with_terrain(m, gs, x, by2, wall, wall_terrain, PRIO_ROOM_FURNITURE);
    }
    for y: by1..by2 {
        write_at_with_terrain(m, gs, bx1, y, wall, wall_terrain, PRIO_ROOM_FURNITURE);
        write_at_with_terrain(m, gs, bx2, y, wall, wall_terrain, PRIO_ROOM_FURNITURE);
    }

    // Fill interior with floor (higher priority so it's clearly inside)
    for y: by1+1..by2-1 {
        for x: bx1+1..bx2-1 {
            write_at_with_terrain(m, gs, x, y, floor, floor_terrain, PRIO_ROOM_FURNITURE);
        }
    }

    // Place one door on a random wall side
    side := random(4);
    if side == 0 {
        // North wall
        dx := bx1 + 1 + random(bx2 - bx1 - 1);
        write_at_with_terrain(m, gs, dx, by1, floor, floor_terrain, PRIO_ROOM_FURNITURE);
    } else if side == 1 {
        // South wall
        dx := bx1 + 1 + random(bx2 - bx1 - 1);
        write_at_with_terrain(m, gs, dx, by2, floor, floor_terrain, PRIO_ROOM_FURNITURE);
    } else if side == 2 {
        // West wall
        dy := by1 + 1 + random(by2 - by1 - 1);
        write_at_with_terrain(m, gs, bx1, dy, floor, floor_terrain, PRIO_ROOM_FURNITURE);
    } else {
        // East wall
        dy := by1 + 1 + random(by2 - by1 - 1);
        write_at_with_terrain(m, gs, bx2, dy, floor, floor_terrain, PRIO_ROOM_FURNITURE);
    }
}

// Write a random town layout: grid of small buildings separated by streets
// In original: case RM_RANDTOWN in DrawPanel (defined but never implemented - fell through to basic room)
// Algorithm: floor-fill for streets, divide into grid cells, ~75% get buildings, outer perimeter walls
write_randtown :: (m: *GenMap, gs: *GenState, r: Rect) {
    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;
    floor_terrain := get_region_floor(gs.current_region, gs.default_floor);
    wall_terrain := get_region_wall(gs.current_region, gs.default_wall);

    w := rect_width(r);
    h := rect_height(r);

    // Need minimum space for a 2x2 grid with streets (7 = 5 min cell + 2 street gap)
    if w < 14 || h < 14 {
        write_room(m, gs, r);
        return;
    }

    // Calculate grid dimensions
    cols : s32 = cast(s32)max(2, min(3, w / 7));
    rows : s32 = cast(s32)max(2, min(4, h / 7));

    // Phase 1: Floor-fill entire rect (creates streets)
    for y: r.y1..r.y2 {
        for x: r.x1..r.x2 {
            write_at_with_terrain(m, gs, x, y, floor, floor_terrain, PRIO_ROOM_FLOOR);
        }
    }

    // Phase 2: Place buildings in grid cells
    // Cell size = available space / grid dims, with 2-tile street gaps between cells
    cell_w : s32 = (w - (cols - 1) * 2) / cols;
    cell_h : s32 = (h - (rows - 1) * 2) / rows;

    // Track how many buildings we placed for minimum guarantee
    buildings_placed : s32 = 0;
    total_cells : s32 = cols * rows;
    cells_remaining : s32 = total_cells;

    for row: 0..rows-1 {
        for col: 0..cols-1 {
            cx1 := r.x1 + cast(s32)col * (cell_w + 2);
            cy1 := r.y1 + cast(s32)row * (cell_h + 2);
            cx2 := cx1 + cell_w - 1;
            cy2 := cy1 + cell_h - 1;

            // Clamp to town bounds
            if cx2 > r.x2  cx2 = r.x2;
            if cy2 > r.y2  cy2 = r.y2;

            cells_remaining -= 1;

            // ~75% chance to place a building, but guarantee at least half are filled
            min_needed := total_cells / 2 - buildings_placed;
            place_building := random(100) < 75;
            if !place_building && min_needed > cells_remaining {
                place_building = true;  // Force placement to meet minimum
            }

            if place_building {
                cell := Rect.{cx1, cy1, cx2, cy2};
                write_town_building(m, gs, cell, wall_terrain, floor_terrain);
                buildings_placed += 1;
            }
        }
    }

    // Phase 3: Outer perimeter walls (where floor meets rock)
    for x: r.x1-1..r.x2+1 {
        if map_get(m, x, r.y1-1) == .ROCK  write_at_with_terrain(m, gs, x, r.y1-1, wall, wall_terrain, PRIO_ROOM_WALL);
        if map_get(m, x, r.y2+1) == .ROCK  write_at_with_terrain(m, gs, x, r.y2+1, wall, wall_terrain, PRIO_ROOM_WALL);
    }
    for y: r.y1-1..r.y2+1 {
        if map_get(m, r.x1-1, y) == .ROCK  write_at_with_terrain(m, gs, r.x1-1, y, wall, wall_terrain, PRIO_ROOM_WALL);
        if map_get(m, r.x2+1, y) == .ROCK  write_at_with_terrain(m, gs, r.x2+1, y, wall, wall_terrain, PRIO_ROOM_WALL);
    }

    // Phase 4: Register room + centers/corners
    if gs.n_centers < 16 {
        cx, cy := rect_center(r);
        gs.centers[gs.n_centers] = cast(u16)(cx + cy * 256);
        gs.n_centers += 1;
    }

    if gs.n_corners < 28 {
        gs.corners[gs.n_corners] = cast(u16)(r.x1 + r.y1 * 256);
        gs.n_corners += 1;
        gs.corners[gs.n_corners] = cast(u16)(r.x2 + r.y1 * 256);
        gs.n_corners += 1;
        gs.corners[gs.n_corners] = cast(u16)(r.x1 + r.y2 * 256);
        gs.n_corners += 1;
        gs.corners[gs.n_corners] = cast(u16)(r.x2 + r.y2 * 256);
        gs.n_corners += 1;
    }

    room: Room;
    room.bounds = r;
    room.connected = false;
    array_add(*m.rooms, room);
}

// Write linked life caves (multiple connected cavern systems)
// In original: case RM_LIFELINK in DrawPanel
// Similar to LIFECAVE but creates multiple connected cavern clusters
write_lifelink :: (m: *GenMap, gs: *GenState, panel: Rect) {
    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;
    floor_terrain := get_region_floor(gs.current_region, gs.default_floor);
    wall_terrain := get_region_wall(gs.current_region, gs.default_wall);

    // Create 2-3 linked cave regions
    num_caves := 2 + random(2);  // 2 or 3 caves
    cave_centers: [4] Point;

    panel_w := rect_width(panel);
    panel_h := rect_height(panel);

    // Place cave centers spread out
    for i: 0..num_caves-1 {
        // Divide panel into regions and place one cave center per region
        region_x := (panel_w / num_caves) * i;
        cx := panel.x1 + region_x + (panel_w / num_caves) / 2 + random(4) - 2;
        cy := panel.y1 + panel_h / 2 + random(panel_h / 3) - panel_h / 6;
        cave_centers[i] = Point.{cx, cy};
    }

    // Generate each cave cluster using cellular automata
    LIFE_PERCENT :: 42;
    BUFFER :: 2;
    ITERATIONS :: 15;

    w := panel_w;
    h := panel_h;

    grid: [..] u8;
    grid.allocator = temp;
    array_resize(*grid, w * h);

    next_grid: [..] u8;
    next_grid.allocator = temp;
    array_resize(*next_grid, w * h);

    // Initialize: everything is wall
    for i: 0..grid.count-1 {
        grid[i] = 1;
    }

    // Seed cave areas around centers
    for cave_idx: 0..num_caves-1 {
        center := cave_centers[cave_idx];
        radius := 5 + random(3);  // Cave cluster radius

        for gy: 0..h-1 {
            for gx: 0..w-1 {
                mx := panel.x1 + cast(s32)gx;
                my := panel.y1 + cast(s32)gy;

                dist := abs(mx - center.x) + abs(my - center.y);  // Manhattan distance
                if dist <= radius {
                    idx := cast(s32)gy * w + cast(s32)gx;
                    if random(100) < (100 - LIFE_PERCENT) {
                        grid[idx] = 0;  // Open
                    }
                }
            }
        }
    }

    // Run cellular automata
    for iter: 0..ITERATIONS-1 {
        for gy: BUFFER..h-BUFFER-1 {
            for gx: BUFFER..w-BUFFER-1 {
                idx := cast(s32)gy * w + cast(s32)gx;

                // Count wall neighbors
                neighbors: s32 = 0;
                for dy: -1..1 {
                    for dx: -1..1 {
                        if dx == 0 && dy == 0 continue;
                        nidx := (cast(s32)gy + cast(s32)dy) * w + (cast(s32)gx + cast(s32)dx);
                        if nidx >= 0 && nidx < grid.count && grid[nidx] == 1 neighbors += 1;
                    }
                }

                if neighbors >= 5 {
                    next_grid[idx] = 1;
                } else if neighbors <= 3 {
                    next_grid[idx] = 0;
                } else {
                    next_grid[idx] = grid[idx];
                }
            }
        }

        for i: 0..grid.count-1 {
            grid[i] = next_grid[i];
        }
    }

    // Connect cave centers with tunnels (ensure connectivity)
    for i: 0..num_caves-2 {
        c1 := cave_centers[i];
        c2 := cave_centers[i + 1];

        // Simple horizontal-then-vertical tunnel
        x1 := c1.x - panel.x1;
        y1 := c1.y - panel.y1;
        x2 := c2.x - panel.x1;
        y2 := c2.y - panel.y1;

        // Horizontal segment
        sx: s32 = cast(s32) ifx x1 < x2 then 1 else -1;
        x := x1;
        while x != x2 {
            if x >= 0 && x < w && y1 >= 0 && y1 < h {
                grid[y1 * w + x] = 0;
            }
            x += sx;
        }

        // Vertical segment
        sy: s32 = cast(s32) ifx y1 < y2 then 1 else -1;
        y := y1;
        while y != y2 {
            if x2 >= 0 && x2 < w && y >= 0 && y < h {
                grid[y * w + x2] = 0;
            }
            y += sy;
        }
    }

    // Write to map
    for gy: 0..h-1 {
        for gx: 0..w-1 {
            idx := cast(s32)gy * w + cast(s32)gx;
            mx := panel.x1 + cast(s32)gx;
            my := panel.y1 + cast(s32)gy;

            if grid[idx] == 0 {
                write_at_with_terrain(m, gs, mx, my, floor, floor_terrain, PRIO_ROOM_FLOOR);
            }
        }
    }

    // Add walls (use full bounds to catch edge tiles)
    for gy: 0..h-1 {
        for gx: 0..w-1 {
            idx := cast(s32)gy * w + cast(s32)gx;
            if grid[idx] == 0 {
                mx := panel.x1 + cast(s32)gx;
                my := panel.y1 + cast(s32)gy;
                for dy: -1..1 {
                    for dx: -1..1 {
                        if dx == 0 && dy == 0 continue;
                        if map_get(m, mx + cast(s32)dx, my + cast(s32)dy) == .ROCK {
                            write_at_with_terrain(m, gs, mx + cast(s32)dx, my + cast(s32)dy, wall, wall_terrain, PRIO_ROOM_WALL);
                        }
                    }
                }
            }
        }
    }

    // Track as room
    room: Room;
    room.bounds = panel;
    room.connected = false;
    array_add(*m.rooms, room);

    if gs.n_centers < 16 {
        cx, cy := rect_center(panel);
        gs.centers[gs.n_centers] = cast(u16)(cx + cy * 256);
        gs.n_centers += 1;
    }
}

// Write a shaped room from a predefined grid (vault or region map)
// In original: case RM_SHAPED in DrawPanel, uses WriteMap with region's Grid
// We use the existing VAULTS array for predefined room layouts
write_shaped :: (m: *GenMap, gs: *GenState, panel: Rect, depth: s32) {
    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;
    floor_terrain := get_region_floor(gs.current_region, gs.default_floor);
    wall_terrain := get_region_wall(gs.current_region, gs.default_wall);

    // Find a suitable vault for this depth
    suitable_vaults: [32] s32;
    suitable_count: s32 = 0;

    for vi: 0..VAULTS.count-1 {
        vault := *VAULTS[vi];
        if vault.min_depth <= depth {
            // Check if vault fits in panel
            if vault.width <= rect_width(panel) - 2 && vault.height <= rect_height(panel) - 2 {
                suitable_vaults[suitable_count] = cast(s32)vi;
                suitable_count += 1;
                if suitable_count >= 32 break;
            }
        }
    }

    if suitable_count == 0 {
        // No suitable vault, fall back to normal room
        r := Rect.{panel.x1 + 2, panel.y1 + 2, panel.x2 - 2, panel.y2 - 2};
        write_room(m, gs, r);
        return;
    }

    // Pick a random vault
    vault := *VAULTS[suitable_vaults[random(suitable_count)]];

    // 50% chance to flip horizontally, 50% to flip vertically (per spec)
    flip_h := random(2) == 0;
    flip_v := random(2) == 0;

    // Calculate placement position (centered in panel)
    start_x := panel.x1 + (rect_width(panel) - vault.width) / 2;
    start_y := panel.y1 + (rect_height(panel) - vault.height) / 2;

    // Parse and place the vault
    row: s32 = 0;
    col: s32 = 0;

    for ch: vault.map_data {
        if ch == #char "\n" {
            row += 1;
            col = 0;
            continue;
        }

        // Calculate actual position with flipping
        actual_col: s32 = cast(s32) ifx flip_h then (vault.width - 1 - col) else col;
        actual_row: s32 = cast(s32) ifx flip_v then (vault.height - 1 - row) else row;

        mx := start_x + actual_col;
        my := start_y + actual_row;

        // Map character to terrain
        if ch == {
            case #char ".";
                write_at_with_terrain(m, gs, mx, my, floor, floor_terrain, PRIO_VAULT);
            case #char "#";
                write_at_with_terrain(m, gs, mx, my, wall, wall_terrain, PRIO_VAULT);
            case #char "+";
                write_at_with_terrain(m, gs, mx, my, .DOOR_CLOSED, null, PRIO_VAULT);
            case #char "~";
                write_at(m, gs, mx, my, .WATER, PRIO_VAULT);
            case #char "^";
                write_at(m, gs, mx, my, .LAVA, PRIO_VAULT);
            case #char "_";
                write_at(m, gs, mx, my, .CHASM, PRIO_VAULT);
            case #char ">";
                write_at_with_terrain(m, gs, mx, my, .STAIRS_DOWN, null, PRIO_VAULT);
            case #char "<";
                write_at_with_terrain(m, gs, mx, my, .STAIRS_UP, null, PRIO_VAULT);
        }

        col += 1;
    }

    // Track as room
    room: Room;
    room.bounds = Rect.{start_x, start_y, start_x + vault.width - 1, start_y + vault.height - 1};
    room.connected = false;
    array_add(*m.rooms, room);

    if gs.n_centers < 16 {
        cx := start_x + vault.width / 2;
        cy := start_y + vault.height / 2;
        gs.centers[gs.n_centers] = cast(u16)(cx + cy * 256);
        gs.n_centers += 1;
    }
}

// Place room within a panel
// Returns the rect where room was placed
place_within_panel :: (panel: Rect, room_w: s32, room_h: s32) -> Rect {
    panel_w := rect_width(panel);
    panel_h := rect_height(panel);

    // Center the room in the panel with some margin
    margin_x := (panel_w - room_w) / 2;
    margin_y := (panel_h - room_h) / 2;

    // Add some randomness to position
    offset_x := random(cast(s32)max(1, margin_x));
    offset_y := random(cast(s32)max(1, margin_y));

    x1 := panel.x1 + offset_x;
    y1 := panel.y1 + offset_y;

    return Rect.{x1, y1, x1 + room_w - 1, y1 + room_h - 1};
}

// Draw a panel with a room
// In original: void Map::DrawPanel(uint8 px, uint8 py, rID regID)
draw_panel :: (m: *GenMap, gs: *GenState, px: s32, py: s32) {
    con := gs.con;

    // Calculate panel bounds
    panel := Rect.{
        px * con.PANEL_SIZEX,
        py * con.PANEL_SIZEY,
        (px + 1) * con.PANEL_SIZEX - 1,
        (py + 1) * con.PANEL_SIZEY - 1
    };

    // Mark panel as drawn
    gs.panels_drawn[py] |= cast(u32)(1 << px);

    // Reset per-panel state
    gs.open_count = 0;
    gs.n_corners = 0;
    gs.n_centers = 0;

    // Choose room type using weighted selection algorithm
    // Original: uses cumulative weight selection, then region constraint filtering
    r_type: s32;
    rm_index: s32;

    // Try up to 200 times to find a valid room type + region combination
    for try: 0..199 {
        r_type, rm_index = select_room_type(*gs.selection, *gs.dungeon_weights);

        // Try to select a region that supports this room type
        // If no valid region found, the room type weight is exhausted and we retry
        if gs.dungeon_weights.room_regions.count > 0 {
            region, ok := select_region(*gs.selection, *gs.dungeon_weights, r_type, *rm_index);
            if ok {
                gs.current_region = region;
                break;
            }
        } else {
            // No regions defined, use room type as-is
            gs.current_region = null;
            break;
        }
    }

    // Per-type room size calculation (original MakeLev.cpp:2460-2749)
    // Each room type has its own sizing formula in the original.
    sx: s32;
    sy: s32;

    // Helper: "large" sizing = max(panel/2, panel - (random(range) + offset))
    // This fills a large portion of the panel with some random variation.
    large_size_x :: (con: DungeonConstants, range: s32, offset: s32) -> s32 {
        return cast(s32)max(con.PANEL_SIZEX / 2, con.PANEL_SIZEX - (random(range) + offset));
    }
    large_size_y :: (con: DungeonConstants, range: s32, offset: s32) -> s32 {
        return cast(s32)max(con.PANEL_SIZEY / 2, con.PANEL_SIZEY - (random(range) + offset));
    }

    // Default: standard room size
    sx = con.ROOM_MINX + random(con.ROOM_MAXX - con.ROOM_MINX);
    sy = con.ROOM_MINY + random(con.ROOM_MAXY - con.ROOM_MINY);

    // Override per type
    if r_type == {
        case RM_LARGE;
            // Original MakeLev.cpp:2490-2492: max(panel/2, panel-(random(8)+2))
            sx = large_size_x(con, 8, 2);
            sy = large_size_y(con, 8, 2);
        case RM_LCIRCLE;
            // Original MakeLev.cpp:2479-2480: max(panel/2, panel-(random(5)+5))
            sx = large_size_x(con, 5, 5);
            sy = large_size_y(con, 5, 5);
        case RM_CROSS;
            // Original MakeLev.cpp:2728-2729: max(panel/2, panel-(random(8)+5))
            sx = large_size_x(con, 8, 5);
            sy = large_size_y(con, 8, 5);
        case RM_MAZE;
            // Original MakeLev.cpp:2502-2503: max(panel/2, panel-(random(8)+2))
            sx = large_size_x(con, 8, 2);
            sy = large_size_y(con, 8, 2);
        case RM_CASTLE; #through;
        case RM_BUILDING;
            // Original MakeLev.cpp:2682-2683: max(panel/2, panel-(random(6)+2))
            sx = large_size_x(con, 6, 2);
            sy = large_size_y(con, 6, 2);
        case RM_CHECKER;
            // Original MakeLev.cpp:2692-2693: ROOM_MIN + random(ROOM_MAX-ROOM_MIN) + 2
            sx = con.ROOM_MINX + random(con.ROOM_MAXX - con.ROOM_MINX) + 2;
            sy = con.ROOM_MINY + random(con.ROOM_MAXY - con.ROOM_MINY) + 2;
        case RM_PILLARS; #through;
        case RM_GRID;
            // Original MakeLev.cpp:2705-2706: ROOM_MIN + random(ROOM_MAX-ROOM_MIN) + 3
            sx = con.ROOM_MINX + random(con.ROOM_MAXX - con.ROOM_MINX) + 3;
            sy = con.ROOM_MINY + random(con.ROOM_MAXY - con.ROOM_MINY) + 3;
        case RM_DOUBLE;
            // Original MakeLev.cpp:2748-2749: ROOM_MIN + random(ROOM_MAX-ROOM_MIN) + 3
            sx = con.ROOM_MINX + random(con.ROOM_MAXX - con.ROOM_MINX) + 3;
            sy = con.ROOM_MINY + random(con.ROOM_MAXY - con.ROOM_MINY) + 3;
        case;
            // RM_NORMAL, RM_CIRCLE, RM_OCTAGON, etc. use default sizing
    }

    // Place room in panel
    r := place_within_panel(panel, sx, sy);

    // For RM_PILLARS/RM_GRID: enforce even dimensions (original MakeLev.cpp:2710-2713)
    if r_type == RM_PILLARS || r_type == RM_GRID {
        if (r.x2 - r.x1) % 2 != 0  r.x2 -= 1;
        if (r.y2 - r.y1) % 2 != 0  r.y2 -= 1;
    }

    // Draw based on room type
    if r_type == {
        case RM_NOROOM;
            // No room - mark as touched anyway
            gs.rooms_touched[py] |= cast(u32)(1 << px);
            return;

        case RM_NORMAL; #through;
        case RM_LARGE;
            write_room(m, gs, r);

        case RM_CIRCLE; #through;
        case RM_LCIRCLE;
            write_circle(m, gs, r);

        case RM_OCTAGON;
            write_octagon(m, gs, r);

        case RM_CROSS;
            write_cross(m, gs, r);

        case RM_LIFECAVE;
            write_lifecave(m, gs, panel);

        case RM_OVERLAP;
            write_overlap(m, gs, panel);

        case RM_ADJACENT;
            write_adjacent(m, gs, panel, use_circles = false, mixed = false);

        case RM_AD_ROUND;
            write_adjacent(m, gs, panel, use_circles = true, mixed = false);

        case RM_AD_MIXED;
            write_adjacent(m, gs, panel, use_circles = false, mixed = true);

        case RM_PILLARS;
            write_pillars(m, gs, r);

        case RM_DOUBLE;
            write_double(m, gs, r);

        case RM_MAZE;
            write_maze(m, gs, r);

        case RM_CHECKER;
            write_checker(m, gs, r);

        case RM_DIAMONDS;
            write_diamonds(m, gs, panel);

        case RM_CASTLE; #through;
        case RM_BUILDING;
            write_castle(m, gs, r);

        case RM_RCAVERN;
            write_rcavern(m, gs, panel);

        case RM_DESTROYED;
            write_destroyed(m, gs, r);

        case RM_GRID;
            write_grid(m, gs, r);

        case RM_LIFELINK;
            write_lifelink(m, gs, panel);

        case RM_SHAPED;
            write_shaped(m, gs, panel, m.depth);

        case RM_RANDTOWN;
            write_randtown(m, gs, r);

        case;
            // Default to normal room
            write_room(m, gs, r);
    }
}

// Cardinal directions for tunnel
TunnelDir :: enum s32 {
    NORTH :: 0;
    EAST :: 1;
    SOUTH :: 2;
    WEST :: 3;
}

TunnelDirX :: s32.[0, 1, 0, -1];  // N, E, S, W
TunnelDirY :: s32.[-1, 0, 1, 0];  // N, E, S, W

// Tunnel constants now in DungeonConstants (gs.con.TURN_CHANCE, etc.)

// Helper: check if two tunnel directions are diametrically opposite
is_diametric :: (a: TunnelDir, b: TunnelDir) -> bool {
    return TunnelDirX[cast(s32)a] + TunnelDirX[cast(s32)b] == 0
        && TunnelDirY[cast(s32)a] + TunnelDirY[cast(s32)b] == 0;
}

// Get direction that corrects toward destination
// In original: Dir Map::CorrectDir(...) at MakeLev.cpp:3611-3639
correct_dir :: (x: s32, y: s32, dx: s32, dy: s32, curr: TunnelDir) -> TunnelDir {
    // If on same row/column, return direct direction unless diametric to current
    // (Original: returns immediately only if !DIAMETRIC)
    direct := TunnelDir.NORTH;  // placeholder
    if x == dx {
        direct = ifx y > dy then .NORTH else .SOUTH;
        if !is_diametric(direct, curr) return direct;
    }
    if y == dy {
        direct = ifx x > dx then .WEST else .EAST;
        if !is_diametric(direct, curr) return direct;
    }

    lx := abs(x - dx);
    ly := abs(y - dy);

    option1: TunnelDir = ifx y > dy then .NORTH else .SOUTH;
    option2: TunnelDir = ifx x > dx then .WEST else .EAST;

    // Prefer the longer axis
    if lx > ly {
        tmp := option1;
        option1 = option2;
        option2 = tmp;
    }

    // Sometimes swap for variety (25% chance)
    if random(4) == 0 {
        tmp := option1;
        option1 = option2;
        option2 = tmp;
    }

    // Don't go back the way we came (diametric check)
    if is_diametric(option1, curr) {
        return option2;
    }
    return option1;
}

// Advanced tunnel carving with turns and segments
// Based on original: uint16 Map::Tunnel(...)
// tflags: TT_* flags controlling termination behavior
carve_tunnel :: (m: *GenMap, gs: *GenState, sx: s32, sy: s32, dx: s32, dy: s32, tflags: u8 = TT_DIRECT | TT_WANDER) {
    corridor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;

    // Pick starting direction based on which axis is longer
    curr_dir: TunnelDir;
    if abs(sx - dx) > abs(sy - dy) {
        curr_dir = ifx sx > dx then .WEST else .EAST;
    } else {
        curr_dir = ifx sy > dy then .NORTH else .SOUTH;
    }

    x := sx;
    y := sy;
    seg_length: s32 = 0;
    total_length: s32 = 0;
    rooms_found: s32 = 0;

    // Get start connection state for TT_CONNECT
    start_connected := false;
    start_cell := get_cell(gs, m, sx, sy);
    if start_cell != null {
        start_connected = start_cell.connected;
    }

    // Store corridor path for later writing
    path: [..] Point;
    path.allocator = temp;

    while total_length < gs.con.MAX_CORRIDOR_LEN {
        // Track rooms touched (for TT_WANDER and TT_NOTOUCH)
        if !(tflags & TT_NOTOUCH) {
            cell := get_cell(gs, m, x, y);
            if cell != null && cell.priority == PRIO_ROOM_FLOOR {
                // Check if we've touched a new room (by panel)
                panel_x := x / gs.con.PANEL_SIZEX;
                panel_y := y / gs.con.PANEL_SIZEY;
                panel_bit := cast(u32)(1 << panel_x);

                if !(gs.rooms_touched[panel_y] & panel_bit) {
                    rooms_found += 1;
                    gs.rooms_touched[panel_y] |= panel_bit;

                    // TT_WANDER: chance to stop after touching 2+ rooms
                    if (tflags & TT_WANDER) && rooms_found >= 2 {
                        if random(rooms_found) != 0 && random(rooms_found) != 0 {
                            break;  // Stop tunneling
                        }
                    }
                }
            }
        }

        // Record position
        array_add(*path, Point.{x, y});
        seg_length += 1;
        total_length += 1;

        // TT_CONNECT: terminate when Connected flag differs from start
        if tflags & TT_CONNECT {
            cell := get_cell(gs, m, x, y);
            if cell != null {
                if cell.connected != start_connected && !is_solid(gs, m, x, y) {
                    break;  // Reached connected/unconnected boundary
                }
            }
        }

        // Move in current direction
        nx := x + TunnelDirX[cast(s32)curr_dir];
        ny := y + TunnelDirY[cast(s32)curr_dir];

        // Check if we need to turn
        force_turn := false;

        // Force turn near map edges (within 4 tiles per spec)
        // Calculate lookahead position in current direction
        look_x := x + TunnelDirX[cast(s32)curr_dir] * 4;
        look_y := y + TunnelDirY[cast(s32)curr_dir] * 4;
        if look_x <= 0 || look_x >= m.width - 1 || look_y <= 0 || look_y >= m.height - 1 {
            force_turn = true;
        }

        // Force turn at vault edges (high priority cells)
        cell := get_cell(gs, m, nx, ny);
        if cell != null && cell.priority >= PRIO_VAULT {
            force_turn = true;
        }

        // Force turn if at destination axis (unless TT_DIRECT)
        if !(tflags & TT_DIRECT) {
            if x == dx && TunnelDirX[cast(s32)curr_dir] != 0 {
                force_turn = true;
            }
            if y == dy && TunnelDirY[cast(s32)curr_dir] != 0 {
                force_turn = true;
            }
        }

        // Force turn if segment too long
        if seg_length > gs.con.SEGMENT_MAXLEN {
            force_turn = true;
        }

        // Random turn chance after minimum segment (if not TT_DIRECT)
        if !force_turn && seg_length > gs.con.SEGMENT_MINLEN && random(100) < gs.con.TURN_CHANCE {
            force_turn = true;
        }

        // Turn if needed
        if force_turn {
            seg_length = 0;
            // TT_DIRECT: always correct toward destination
            // Otherwise: usually correct, sometimes go random (STUBBORN_CORRIDOR)
            if (tflags & TT_DIRECT) || random(100) > gs.con.STUBBORN_CORRIDOR {
                curr_dir = correct_dir(x, y, dx, dy, curr_dir);
            } else {
                // Random perpendicular turn
                old_dir := curr_dir;
                while curr_dir == old_dir {
                    curr_dir = cast(TunnelDir) random(4);
                }
            }

            // Hard edge clamping: override direction if within 2-3 tiles of edge
            // Per spec: MakeLev.cpp:3534-3541
            if x <= 2 {
                curr_dir = .EAST;
            } else if x >= m.width - 3 {
                curr_dir = .WEST;
            } else if y <= 2 {
                curr_dir = .SOUTH;
            } else if y >= m.height - 3 {
                curr_dir = .NORTH;
            }
        }

        // Move
        x = nx;
        y = ny;

        // Check termination conditions (unless TT_EXACT)
        if !(tflags & TT_EXACT) {
            // Close enough and in open space
            distance := abs(x - dx) + abs(y - dy);
            if distance < 10 && !is_solid(gs, m, x, y) {
                // Same panel as destination
                curr_px := x / gs.con.PANEL_SIZEX;
                curr_py := y / gs.con.PANEL_SIZEY;
                dest_px := dx / gs.con.PANEL_SIZEX;
                dest_py := dy / gs.con.PANEL_SIZEY;

                if curr_px == dest_px && curr_py == dest_py {
                    break;
                }
            }
        } else {
            // TT_EXACT: stop when we reach exact destination
            if x == dx && y == dy {
                break;
            }
        }
    }

    // Write the corridor
    for p: path {
        if map_get(m, p.x, p.y) == .ROCK {
            map_set(m, p.x, p.y, corridor);

            // Update cell info
            cell := get_cell(gs, m, p.x, p.y);
            if cell != null {
                cell.priority = PRIO_CORRIDOR_FLOOR;
                cell.solid = false;
            }

            // Add walls around corridor
            for dy: -1..1 {
                for dx: -1..1 {
                    if dx == 0 && dy == 0 continue;
                    wx := p.x + cast(s32)dx;
                    wy := p.y + cast(s32)dy;
                    if map_get(m, wx, wy) == .ROCK {
                        map_set(m, wx, wy, wall);
                        wcell := get_cell(gs, m, wx, wy);
                        if wcell != null && wcell.priority < PRIO_CORRIDOR_WALL {
                            wcell.priority = PRIO_CORRIDOR_WALL;
                        }
                    }
                }
            }
        }
    }
}

// Simple L-shaped corridor (fallback)
carve_corridor :: (m: *GenMap, gs: *GenState, sx: s32, sy: s32, dx: s32, dy: s32) {
    // Use advanced tunnel instead
    carve_tunnel(m, gs, sx, sy, dx, dy);
}

// Legacy simple corridor for comparison
carve_corridor_simple :: (m: *GenMap, gs: *GenState, sx: s32, sy: s32, dx: s32, dy: s32) {
    corridor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;

    x := sx;
    y := sy;

    // Horizontal first or vertical first based on random
    horizontal_first := random(2) == 0;

    if horizontal_first {
        // Horizontal
        step_x: s32 = cast(s32) ifx dx > x then 1 else -1;
        while x != dx {
            if map_get(m, x, y) == .ROCK {
                map_set(m, x, y, corridor);
                if map_get(m, x, y-1) == .ROCK  map_set(m, x, y-1, wall);
                if map_get(m, x, y+1) == .ROCK  map_set(m, x, y+1, wall);
            }
            x += step_x;
        }
        // Vertical
        step_y: s32 = cast(s32) ifx dy > y then 1 else -1;
        while y != dy {
            if map_get(m, x, y) == .ROCK {
                map_set(m, x, y, corridor);
                if map_get(m, x-1, y) == .ROCK  map_set(m, x-1, y, wall);
                if map_get(m, x+1, y) == .ROCK  map_set(m, x+1, y, wall);
            }
            y += step_y;
        }
    } else {
        // Vertical first
        step_y: s32 = cast(s32) ifx dy > y then 1 else -1;
        while y != dy {
            if map_get(m, x, y) == .ROCK {
                map_set(m, x, y, corridor);
                if map_get(m, x-1, y) == .ROCK  map_set(m, x-1, y, wall);
                if map_get(m, x+1, y) == .ROCK  map_set(m, x+1, y, wall);
            }
            y += step_y;
        }
        // Horizontal
        step_x: s32 = cast(s32) ifx dx > x then 1 else -1;
        while x != dx {
            if map_get(m, x, y) == .ROCK {
                map_set(m, x, y, corridor);
                if map_get(m, x, y-1) == .ROCK  map_set(m, x, y-1, wall);
                if map_get(m, x, y+1) == .ROCK  map_set(m, x, y+1, wall);
            }
            x += step_x;
        }
    }
}

// Connect panels with corridors
// In original: MakeLev.cpp:1616-1696, "Step 5: Connect Each Panel"
// Uses edge-tile detection + closest-pair matching between panels
connect_panels :: (m: *GenMap, gs: *GenState) {
    MAX_EDGE_POINTS :: 200;  // Max edge points tracked per panel

    // Per-panel edge point storage
    PanelEdges :: struct {
        points: [MAX_EDGE_POINTS] Point;
        count: s32;
    }

    num_panels := gs.panels_x * gs.panels_y;
    edges: [..] PanelEdges;
    edges.allocator = temp;
    array_resize(*edges, num_panels);

    // Phase 1: Find edge floor tiles in each panel
    // An "edge" tile is a non-solid tile with at least one solid cardinal neighbor
    // (Original: MakeLev.cpp:1634-1656)
    for py: 0..gs.panels_y-1 {
        for px: 0..gs.panels_x-1 {
            panel_num := cast(s32)py * gs.panels_x + cast(s32)px;
            pe := *edges[panel_num];
            pe.count = 0;

            base_x := cast(s32)px * gs.con.PANEL_SIZEX;
            base_y := cast(s32)py * gs.con.PANEL_SIZEY;

            for ly: 0..gs.con.PANEL_SIZEY-1 {
                for lx: 0..gs.con.PANEL_SIZEX-1 {
                    x := base_x + cast(s32)lx;
                    y := base_y + cast(s32)ly;

                    if is_solid(gs, m, x, y) continue;

                    // Count non-solid cardinal neighbors
                    open_count : s32 = 0;
                    if x > 0         && !is_solid(gs, m, x-1, y) then open_count += 1;
                    if x < m.width-1 && !is_solid(gs, m, x+1, y) then open_count += 1;
                    if y > 0         && !is_solid(gs, m, x, y-1) then open_count += 1;
                    if y < m.height-1&& !is_solid(gs, m, x, y+1) then open_count += 1;

                    // Has at least one solid neighbor = edge tile
                    if open_count < 4 && pe.count < MAX_EDGE_POINTS {
                        pe.points[pe.count] = Point.{x, y};
                        pe.count += 1;
                    }
                }
            }
        }
    }

    // Phase 2: Connect adjacent panels using closest edge pairs
    // Original connects: left, up, diagonal-up-left (MakeLev.cpp:1658-1696)
    for py: 0..gs.panels_y-1 {
        for px: 0..gs.panels_x-1 {
            pn1 := cast(s32)py * gs.panels_x + cast(s32)px;

            // Build neighbor list: left, up, diagonal-up-left
            neighbors: [3] s32;
            nc : s32 = 0;

            if px > 0 {
                neighbors[nc] = cast(s32)py * gs.panels_x + (cast(s32)px - 1);
                nc += 1;
            }
            if py > 0 {
                neighbors[nc] = (cast(s32)py - 1) * gs.panels_x + cast(s32)px;
                nc += 1;
            }
            if py > 0 && px > 0 {
                neighbors[nc] = (cast(s32)py - 1) * gs.panels_x + (cast(s32)px - 1);
                nc += 1;
            }

            pe1 := *edges[pn1];
            if pe1.count == 0 continue;

            for k: 0..nc-1 {
                pn2 := neighbors[cast(s32)k];
                pe2 := *edges[pn2];
                if pe2.count == 0 continue;

                // Find closest pair of edge points between panels
                best_dist := m.width * m.height;
                bsx : s32 = 0;
                bsy : s32 = 0;
                bdx : s32 = 0;
                bdy : s32 = 0;

                for i: 0..pe1.count-1 {
                    p1 := pe1.points[cast(s32)i];
                    for j: 0..pe2.count-1 {
                        p2 := pe2.points[cast(s32)j];
                        d := abs(p1.x - p2.x) + abs(p1.y - p2.y);
                        if d < best_dist {
                            best_dist = d;
                            bsx = p1.x;
                            bsy = p1.y;
                            bdx = p2.x;
                            bdy = p2.y;
                        }
                    }
                }

                if best_dist < m.width * m.height {
                    carve_tunnel(m, gs, bsx, bsy, bdx, bdy);
                }
            }
        }
    }
}

// Note: Dir enum and DirX/DirY functions are defined in defines.jai

// Write a streamer (river or chasm) across the map
// In original: void Map::WriteStreamer(Rect &r, uint8 sx, uint8 sy, Dir d, rID regID)
// Original: WriteStreamer(Rect &r, uint8 sx, uint8 sy, Dir d, rID regID)
// Caller passes random map coordinates; rivers override to start from edge.
write_streamer :: (m: *GenMap, gs: *GenState, stype: StreamerType) {
    info := STREAMER_INFO[cast(s32) stype];
    terrain := info.terrain;
    is_river := info.is_river;

    // Starting position: random point on map (original MakeLev.cpp:1424-1425)
    sx : s32 = 1 + random(m.width - 2);
    sy : s32 = 1 + random(m.height - 2);
    dir: Dir;

    // Width control
    width: s32;
    max_width: s32;

    if is_river {
        // Rivers: fixed width, start from edge (original MakeLev.cpp:848-856)
        width = 2 + random(4);
        max_width = width;
        if sx > sy {
            sy = 0;
            dir = ifx random(2) != 0 then Dir.SOUTHEAST else Dir.SOUTHWEST;
        } else {
            sx = 0;
            dir = ifx random(2) != 0 then Dir.SOUTHEAST else Dir.NORTHEAST;
        }
    } else {
        // Non-rivers: start at 1 width, grow to max (original MakeLev.cpp:858-863)
        width = 1;
        max_width = 2 + random(gs.con.MAX_STREAMER_WIDTH);
        // Random diagonal direction
        droll := random(4);
        if droll == 0       dir = Dir.SOUTHEAST;
        else if droll == 1  dir = Dir.SOUTHWEST;
        else if droll == 2  dir = Dir.NORTHEAST;
        else                dir = Dir.NORTHWEST;
    }

    // Chasms: minimum width 4 (original MakeLev.cpp:866-867)
    if stype == .CHASM {
        max_width = cast(s32)max(4, max_width + 1);
    }

    // Meander ratios (original MakeLev.cpp:869-870)
    rx := 2 + random(10);
    ry := 2 + random(10);

    midpoint := false;

    // Walk across the map (original MakeLev.cpp:873-909)
    while width > 0 && sx >= 0 && sx < m.width && sy >= 0 && sy < m.height {
        // Non-rivers vary width (original: !random(13))
        if !is_river && random(13) == 0 {
            if midpoint {
                width -= 1;
            } else {
                width += 1;
            }
        }

        // Move in direction (original: random(rx+ry)+1 <= rx)
        if random(rx + ry) + 1 <= rx {
            sx += DirX(dir);
        } else {
            sy += DirY(dir);
        }

        if width >= max_width {
            midpoint = true;
        }

        // Draw width x width square centered at position
        mx := sx - (width / 2);
        my := sy - (width / 2);
        for iy: 0..width-1 {
            for ix: 0..width-1 {
                tx := mx + cast(s32)ix;
                ty := my + cast(s32)iy;
                if tx >= 1 && tx < m.width - 1 && ty >= 1 && ty < m.height - 1 {
                    write_at(m, gs, tx, ty, terrain, info.priority);
                }
            }
        }
    }
}

// Legacy version for backward compatibility
write_streamer :: (m: *GenMap, terrain: Terrain, is_river: bool = false) {
    // Determine streamer type from terrain and is_river
    stype: StreamerType;
    if terrain == .WATER {
        stype = ifx is_river then .WATER_RIVER else .WATER_STREAM;
    } else if terrain == .CHASM {
        stype = .CHASM;
    } else {
        stype = .RUBBLE;
    }

    // Create temp GenState for legacy calls
    gs: GenState;
    gen_state_init(*gs);
    write_streamer(m, *gs, stype);
}

// Write a vault (pre-designed special room) at a position
// Returns true if vault was placed successfully
write_vault :: (m: *GenMap, gs: *GenState, vault_idx: s32, x: s32, y: s32) -> bool {
    if vault_idx < 0 || vault_idx >= VAULTS.count return false;

    vault := VAULTS[vault_idx];

    // Check if vault fits at position
    if x + vault.width > m.width - 1 return false;
    if y + vault.height > m.height - 1 return false;
    if x < 1 || y < 1 return false;

    // Check if area is clear (all rock)
    for vy: 0..vault.height-1 {
        for vx: 0..vault.width-1 {
            cell := get_cell(gs, m, x + vx, y + vy);
            if cell != null && cell.priority > PRIO_EMPTY {
                return false;  // Something already here
            }
        }
    }

    // Parse and place the vault
    map_chars := vault.map_data.data;
    map_len := vault.map_data.count;
    vx: s32 = 0;
    vy: s32 = 0;

    for i: 0..map_len-1 {
        ch := map_chars[i];

        if ch == #char "\n" {
            vy += 1;
            vx = 0;
            continue;
        }

        if vx >= vault.width || vy >= vault.height continue;

        terrain: Terrain;

        if ch == {
            case #char "#";  terrain = .WALL;
            case #char ".";  terrain = .FLOOR;
            case #char "+";  terrain = .DOOR_CLOSED;
            case #char "~";  terrain = .WATER;
            case #char "^";  terrain = .LAVA;
            case #char "_";  terrain = .CHASM;
            case #char ">";  terrain = .STAIRS_DOWN;
            case #char "<";  terrain = .STAIRS_UP;
            case #char " ";
                vx += 1;
                continue;  // Skip spaces
            case;
                vx += 1;
                continue;  // Unknown character
        }

        write_at(m, gs, x + vx, y + vy, terrain, PRIO_VAULT);

        // Mark as vault cell
        cell := get_cell(gs, m, x + vx, y + vy);
        if cell != null {
            cell.priority = PRIO_VAULT;
        }

        vx += 1;
    }

    // Track as a room
    room: Room;
    room.bounds = Rect.{x, y, x + vault.width - 1, y + vault.height - 1};
    room.connected = false;
    array_add(*m.rooms, room);

    return true;
}

// Try to place a random vault somewhere in the dungeon
// Returns true if a vault was placed
try_place_vault :: (m: *GenMap, gs: *GenState, depth: s32) -> bool {
    // Build list of valid vaults for this depth
    valid_vaults: [..] s32;
    valid_vaults.allocator = temp;

    for i: 0..VAULTS.count-1 {
        if VAULTS[i].min_depth <= depth {
            array_add(*valid_vaults, cast(s32)i);
        }
    }

    if valid_vaults.count == 0 return false;

    // Pick a random vault
    vault_idx := valid_vaults[random(cast(s32)valid_vaults.count)];
    vault := VAULTS[vault_idx];

    // Try random positions
    MAX_TRIES :: 50;
    for try: 0..MAX_TRIES-1 {
        x := 2 + random(m.width - vault.width - 4);
        y := 2 + random(m.height - vault.height - 4);

        if write_vault(m, gs, vault_idx, x, y) {
            return true;
        }
    }

    return false;
}

// Place doors where floor meets wall with floor on opposite side
// This finds corridor entrances to rooms
// Per spec (Feature.cpp:310-337):
// - 10% open
// - ~45% closed+locked (50% of remaining 90%)
// - ~45% closed+unlocked
// - ~14% secret (checked separately, can override open)
place_doors_makelev :: (m: *GenMap, depth: s32 = 1) {
    for y: 1..m.height-2 {
        for x: 1..m.width-2 {
            // Check if this is a wall
            if map_get(m, x, y) != .WALL continue;

            is_vertical := false;
            is_horizontal := false;

            // Check for horizontal door position (floor on left and right)
            if map_get(m, x-1, y) == .FLOOR && map_get(m, x+1, y) == .FLOOR {
                // Make sure we're not in an open area (need walls above and below)
                above := map_get(m, x, y-1);
                below := map_get(m, x, y+1);
                if (above == .WALL || above == .ROCK) && (below == .WALL || below == .ROCK) {
                    is_horizontal = true;
                }
            }

            // Check for vertical door position (floor above and below)
            if !is_horizontal && map_get(m, x, y-1) == .FLOOR && map_get(m, x, y+1) == .FLOOR {
                // Make sure we're not in an open area (need walls left and right)
                left := map_get(m, x-1, y);
                right := map_get(m, x+1, y);
                if (left == .WALL || left == .ROCK) && (right == .WALL || right == .ROCK) {
                    is_vertical = true;
                }
            }

            if !is_horizontal && !is_vertical continue;

            // Create door with random state per spec
            // Per spec: 10% open, ~14% secret (overrides open), 50% of remaining locked
            door: DoorInfo;
            door.x = x;
            door.y = y;
            door.flags = 0;

            if is_vertical {
                door.flags |= DF_VERTICAL;
            }

            // Determine door state
            is_open := random(100) < 10;     // 10% open
            is_secret := random(100) < 14;   // ~14% secret (overrides open)
            is_locked := random(2) == 0;     // 50% chance locked (if closed)

            if is_secret {
                door.flags |= DF_SECRET;
                map_set(m, x, y, .DOOR_SECRET);
            } else if is_open {
                door.flags |= DF_OPEN;
                map_set(m, x, y, .DOOR_OPEN);
            } else {
                // Closed door - check if locked
                if is_locked {
                    door.flags |= DF_LOCKED;
                    // Lock DC scales with depth
                    door.lock_dc = 10 + depth * 2 + random(5);
                }
                map_set(m, x, y, .DOOR_CLOSED);
            }

            // Add to doors array
            array_add(*m.doors, door);
        }
    }
}

// ============================================================================
// Trap Placement
// Source: MakeLev.cpp:2155-2192
// ============================================================================

// Trap chance constant (from Defines.h:3643)
TRAP_CHANCE :: 73;

// Check if a tile is a door
is_door :: (t: Terrain) -> bool {
    return t == .DOOR_CLOSED || t == .DOOR_OPEN || t == .DOOR_SECRET;
}

// Check if a tile is solid (wall or rock) but not a door
is_solid_not_door :: (m: *GenMap, x: s32, y: s32) -> bool {
    t := map_get(m, x, y);
    return (t == .WALL || t == .ROCK) && !is_door(t);
}

// ============================================================================
// Lighting Placement
// ============================================================================

// Lighting constants (from MakeLev.cpp)
ROOM_LIT_CHANCE      :: 50;   // Base % chance room is lit
LIT_CHANCE_DEPTH_MOD :: 4;    // % reduction per depth
TORCH_DENSITY        :: 10;   // 1-in-N wall tiles get torch in lit rooms

// Place torches in rooms based on depth
// Source: MakeLev.cpp lighting system
place_room_lights :: (m: *GenMap, gs: *GenState, depth: s32) {
    torches_placed: s32 = 0;

    for room, room_idx: m.rooms {
        // Check if room should be lit (chance decreases with depth)
        lit_chance := ROOM_LIT_CHANCE - (LIT_CHANCE_DEPTH_MOD * depth);
        if lit_chance < 5 lit_chance = 5;  // Minimum 5% chance

        if random(100) >= lit_chance continue;

        // This room is lit - place torches on wall tiles adjacent to floor
        r := room.bounds;

        // Check walls around the room perimeter
        // Top wall
        for x: r.x1..r.x2 {
            if is_wall_adjacent_to_floor(m, x, r.y1 - 1, .SOUTH) {
                if random(TORCH_DENSITY) == 0 {
                    place_torch(m, x, r.y1 - 1);
                    torches_placed += 1;
                }
            }
        }
        // Bottom wall
        for x: r.x1..r.x2 {
            if is_wall_adjacent_to_floor(m, x, r.y2 + 1, .NORTH) {
                if random(TORCH_DENSITY) == 0 {
                    place_torch(m, x, r.y2 + 1);
                    torches_placed += 1;
                }
            }
        }
        // Left wall
        for y: r.y1..r.y2 {
            if is_wall_adjacent_to_floor(m, r.x1 - 1, y, .EAST) {
                if random(TORCH_DENSITY) == 0 {
                    place_torch(m, r.x1 - 1, y);
                    torches_placed += 1;
                }
            }
        }
        // Right wall
        for y: r.y1..r.y2 {
            if is_wall_adjacent_to_floor(m, r.x2 + 1, y, .WEST) {
                if random(TORCH_DENSITY) == 0 {
                    place_torch(m, r.x2 + 1, y);
                    torches_placed += 1;
                }
            }
        }
    }

    if torches_placed > 0 && !makelev_quiet {
        print("  Placed % torches on level %\n", torches_placed, depth);
    }
}

// Check if a wall tile is adjacent to floor in the specified direction
is_wall_adjacent_to_floor :: (m: *GenMap, x: s32, y: s32, dir: Dir) -> bool {
    // Must be a wall tile
    t := map_get(m, x, y);
    if t != .WALL return false;

    // Check the tile in the specified direction
    adj_x := x + DirX(dir);
    adj_y := y + DirY(dir);
    adj_t := map_get(m, adj_x, adj_y);

    return adj_t == .FLOOR;
}

// Place a torch at the given position
place_torch :: (m: *GenMap, x: s32, y: s32) {
    if !map_in_bounds(m, x, y) return;

    // Record torch position for lighting calculation
    torch: TorchPos;
    torch.x = x;
    torch.y = y;
    array_add(*m.torch_positions, torch);

    // Torches are visual markers on walls - we'll use a custom glyph
    // Set tile display to show torch character (GLYPH_TORCH defined in glyph_cp437.jai)
    td := map_get_display(m, x, y);
    if td != null {
        td.glyph = GLYPH_TORCH;
        td.fg_color = YELLOW;  // Bright yellow/orange for torch
        td.use_custom = true;
    }
}

// Place traps at doors and corridor bottlenecks
// Source: MakeLev.cpp:2155-2192
place_traps :: (m: *GenMap, depth: s32) {
    // Calculate DepthCR (simplified - full version uses INITIAL_CR + Depth * DUN_SPEED / 100 - 1)
    // For now, use depth directly as CR approximation
    depth_cr := depth;

    traps_placed := 0;

    for y: 1..m.height-2 {
        for x: 1..m.width-2 {
            t := map_get(m, x, y);

            // Case 1: Trap at door
            // Chance: random(TRAP_CHANCE) <= DepthCR + 10
            if is_door(t) {
                if random(TRAP_CHANCE) <= depth_cr + 10 {
                    // Place trap (door becomes trapped door - for now just mark the tile)
                    // In full implementation, this would set DF_TRAPPED flag on the door
                    // For visualization, we'll place a hidden trap adjacent to the door
                    // (Real traps on doors would need door flag support)
                    traps_placed += 1;
                }
                continue;
            }

            // Case 2: Trap at corridor bottleneck
            // Must be non-solid, non-door floor/corridor
            if t != .FLOOR && t != .CORRIDOR continue;

            // Check for bottleneck pattern:
            // Pattern 1: walls left and right, open above and below
            // Pattern 2: walls above and below, open left and right
            up := map_get(m, x, y - 1);
            down := map_get(m, x, y + 1);
            left := map_get(m, x - 1, y);
            right := map_get(m, x + 1, y);

            up_solid := is_solid_not_door(m, x, y - 1);
            down_solid := is_solid_not_door(m, x, y + 1);
            left_solid := is_solid_not_door(m, x - 1, y);
            right_solid := is_solid_not_door(m, x + 1, y);

            up_open := !terrain_solid(up) || is_door(up);
            down_open := !terrain_solid(down) || is_door(down);
            left_open := !terrain_solid(left) || is_door(left);
            right_open := !terrain_solid(right) || is_door(right);

            is_bottleneck := false;

            // Horizontal corridor (walls above and below, open left and right)
            if up_solid && down_solid && left_open && right_open {
                is_bottleneck = true;
            }
            // Vertical corridor (walls left and right, open above and below)
            if left_solid && right_solid && up_open && down_open {
                is_bottleneck = true;
            }

            if is_bottleneck {
                // Chance: random(TRAP_CHANCE) <= (DepthCR + 2) / 3
                if random(TRAP_CHANCE) <= (depth_cr + 2) / 3 {
                    // Place hidden trap
                    map_set(m, x, y, .TRAP_HIDDEN);
                    traps_placed += 1;
                }
            }
        }
    }

    if traps_placed > 0 && !makelev_quiet {
        print("  Placed % traps on level %\n", traps_placed, depth);
    }
}

// Place treasure deposits in fully-enclosed rock tiles
// Per spec: MakeLev.cpp:2155-2192, count = 1d4 + Depth
// Treasure is placed in tiles fully surrounded by solid rock
place_treasure_deposits :: (m: *GenMap, depth: s32) {
    // Count: 1d4 + Depth
    num_deposits := (1 + random(4)) + depth;
    deposits_placed: s32 = 0;

    // Try to find valid positions for deposits
    // Per spec: Must be in solid rock, fully surrounded by solid rock
    // Prefers non-base rock terrain (special rock veins)
    for attempt: 0..num_deposits * 50 - 1 {  // 50 tries per deposit
        // Random position, avoiding edges
        x := 2 + random(m.width - 4);
        y := 2 + random(m.height - 4);

        // Check if position is rock
        if map_get(m, x, y) != .ROCK continue;

        // Check if fully surrounded by solid rock (all 8 neighbors)
        all_solid := true;
        for dy: -1..1 {
            for dx: -1..1 {
                if dx == 0 && dy == 0 continue;
                t := map_get(m, x + cast(s32)dx, y + cast(s32)dy);
                if t != .ROCK && t != .WALL {
                    all_solid = false;
                    break;
                }
            }
            if !all_solid break;
        }

        if !all_solid continue;

        // Valid deposit location - place a treasure marker
        // Keep it as rock visually (hidden), but mark with an item
        // Mining will reveal these as treasures

        // Add an item at this location (will be hidden until uncovered)
        item: EntityPos;
        item.x = x;
        item.y = y;
        item.cr = depth + 3;  // Treasure is higher quality
        item.type_id = 999;   // Special treasure marker (overwritten if found in db)
        db := get_resource_db();
        assign_item_from_db(db, *item);
        array_add(*m.items, item);

        deposits_placed += 1;

        if deposits_placed >= num_deposits {
            break;
        }
    }

    if deposits_placed > 0 && !makelev_quiet {
        print("  Placed % treasure deposits\n", deposits_placed);
    }
}

// ============================================================================
// Furnishing System
// Source: MakeLev.cpp:2951-3266 (FurnishArea)
//         Defines.h:3828-3843 (FU_* constants)
// ============================================================================

// Furnishing types from Defines.h:3828-3843
FurnishType :: enum {
    FU_NONE;
    FU_SPLATTER;              // Random scatter
    FU_TRAIL;                 // Not implemented
    FU_LIFEBLOB;              // Cellular automata patches
    FU_GRID;                  // Regular 2x2 grid
    FU_COLUMNS;               // Alternating rows/columns
    FU_CENTER;                // Room center points
    FU_RANDOM;                // Single random placement
    FU_TABLE;                 // Table placement
    FU_BED;                   // Bed placement
    FU_CORNERS;               // Corner positions
    FU_XCORNERS;              // Extended corners
    FU_SPACED_COLUMNS;        // Widely spaced columns
    FU_CENTER_CIRCLE_SMALL;   // Small circle at center
    FU_CENTER_CIRCLE_MEDIUM;  // Medium circle at center
    FU_CENTER_CIRCLE_LARGE;   // Large circle at center
    FU_INNER_COLUMNS;         // Columns with 2-tile border
}

// Apply furnishing pattern to a room
// Source: MakeLev.cpp:2951-3266
furnish_area :: (m: *GenMap, room: Room, pattern: FurnishType, terrain: Terrain = .PILLAR) {
    if pattern == .FU_NONE return;

    r := room.bounds;
    room_w := rect_width(r);
    room_h := rect_height(r);

    if room_w < 4 || room_h < 4 return;  // Too small to furnish

    if pattern == {
        case .FU_SPLATTER;
            // Random scatter: ~1/5 of room volume
            // Source: MakeLev.cpp:3058-3068
            count := room_w * room_h / 5;
            for i: 0..count-1 {
                x := r.x1 + 1 + random(room_w - 2);
                y := r.y1 + 1 + random(room_h - 2);
                if map_get(m, x, y) == .FLOOR {
                    map_set(m, x, y, terrain);
                }
            }

        case .FU_GRID;
            // Regular 2x2 grid with 1-tile border
            // Source: MakeLev.cpp:3107-3113
            for x: 0..(room_w-3)/2 {
                for y: 0..(room_h-3)/2 {
                    px := r.x1 + 1 + x * 2;
                    py := r.y1 + 1 + y * 2;
                    if map_get(m, px, py) == .FLOOR {
                        map_set(m, px, py, terrain);
                    }
                }
            }

        case .FU_COLUMNS;
            // 50% vertical bars, 50% horizontal bars
            // Source: MakeLev.cpp:3129-3141
            if random(2) == 0 {
                // Vertical bars
                for x: 0..(room_w-3)/2 {
                    px := r.x1 + 1 + x * 2;
                    for y: 1..room_h-2 {
                        py := r.y1 + y;
                        if map_get(m, px, py) == .FLOOR {
                            map_set(m, px, py, terrain);
                        }
                    }
                }
            } else {
                // Horizontal bars
                for y: 0..(room_h-3)/2 {
                    py := r.y1 + 1 + y * 2;
                    for x: 1..room_w-2 {
                        px := r.x1 + x;
                        if map_get(m, px, py) == .FLOOR {
                            map_set(m, px, py, terrain);
                        }
                    }
                }
            }

        case .FU_CORNERS;
            // Place in corners
            // Source: MakeLev.cpp:3116-3127
            corners := s32.[
                r.x1 + 1, r.y1 + 1,  // Top-left
                r.x2 - 1, r.y1 + 1,  // Top-right
                r.x1 + 1, r.y2 - 1,  // Bottom-left
                r.x2 - 1, r.y2 - 1   // Bottom-right
            ];
            for i: 0..3 {
                x := corners[i * 2];
                y := corners[i * 2 + 1];
                if map_get(m, x, y) == .FLOOR {
                    map_set(m, x, y, terrain);
                }
            }

        case .FU_CENTER;
            // Place at center
            cx, cy := rect_center(r);
            if map_get(m, cx, cy) == .FLOOR {
                map_set(m, cx, cy, terrain);
            }

        case .FU_SPACED_COLUMNS;
            // Widely spaced columns (every 3 tiles)
            for x: 0..(room_w-3)/3 {
                for y: 0..(room_h-3)/3 {
                    px := r.x1 + 1 + x * 3;
                    py := r.y1 + 1 + y * 3;
                    if map_get(m, px, py) == .FLOOR {
                        map_set(m, px, py, terrain);
                    }
                }
            }

        case .FU_INNER_COLUMNS;
            // Columns with 2-tile border
            for x: 0..(room_w-5)/2 {
                for y: 0..(room_h-5)/2 {
                    px := r.x1 + 2 + x * 2;
                    py := r.y1 + 2 + y * 2;
                    if map_get(m, px, py) == .FLOOR {
                        map_set(m, px, py, terrain);
                    }
                }
            }
    }
}

// Choose and apply a random furnishing pattern to a room
// Called after room generation for visual variety
furnish_room :: (m: *GenMap, room: Room) {
    // Only furnish larger rooms
    room_w := rect_width(room.bounds);
    room_h := rect_height(room.bounds);
    if room_w < 6 || room_h < 6 return;

    // 30% chance to add furnishing
    if random(100) >= 30 return;

    // Weighted pattern selection
    roll := random(100);
    pattern: FurnishType;

    if roll < 25 {
        pattern = .FU_CORNERS;
    } else if roll < 45 {
        pattern = .FU_SPACED_COLUMNS;
    } else if roll < 60 {
        pattern = .FU_INNER_COLUMNS;
    } else if roll < 75 {
        pattern = .FU_CENTER;
    } else if roll < 90 {
        pattern = .FU_SPLATTER;
    } else {
        pattern = .FU_NONE;  // No furnishing
    }

    furnish_area(m, room, pattern);
}

// ============================================================================
// Population System
// Source: MakeLev.cpp:3269-3301 (PopulatePanel)
//         Encounter.cpp:514-1125 (enGenerate)
//         Encounter.cpp:500-512 (maxAmtByCR)
// ============================================================================

// Monster count caps by CR (from Encounter.cpp:500-512)
// maxAmtByCR limits how many monsters of a given CR can appear
max_monsters_by_cr :: (cr: s32) -> s32 {
    if cr <= 1 return 5;
    if cr == 2 return 7;
    if cr == 3 return 10;
    if cr == 4 return 12;
    if cr == 5 return 15;
    return 50;  // CR > 5
}

// Calculate monster density based on depth
// Source: Encounter.cpp:545-549
// Returns divisor for open tile count
monster_density_divisor :: (depth: s32) -> s32 {
    if depth > 2 return 30;   // 1 monster per 30 open tiles
    if depth == 2 return 50;  // 1 monster per 50 open tiles
    return 75;                // Depth 1: 1 monster per 75 open tiles
}

// Check if a position is valid for monster/item placement
is_valid_entity_pos :: (m: *GenMap, x: s32, y: s32) -> bool {
    if x <= 0 || y <= 0 || x >= m.width - 1 || y >= m.height - 1 {
        return false;
    }

    t := map_get(m, x, y);

    // Must be walkable floor or corridor
    if t != .FLOOR && t != .CORRIDOR {
        return false;
    }

    return true;
}

// Check if position already has a monster
has_monster_at :: (m: *GenMap, x: s32, y: s32) -> bool {
    for mon: m.monsters {
        if mon.x == x && mon.y == y return true;
    }
    return false;
}

// Check if position already has an item
has_item_at :: (m: *GenMap, x: s32, y: s32) -> bool {
    for item: m.items {
        if item.x == x && item.y == y return true;
    }
    return false;
}

// Count open (walkable) tiles on the map
count_open_tiles :: (m: *GenMap) -> s32 {
    count: s32 = 0;
    for y: 1..m.height-2 {
        for x: 1..m.width-2 {
            t := map_get(m, x, y);
            if t == .FLOOR || t == .CORRIDOR {
                count += 1;
            }
        }
    }
    return count;
}

// Item generation chances (from population.md)
// These are indices into a conceptual Con[] array in original
CHEST_CHANCE    :: 15;   // % chance for chest in room
TREASURE_CHANCE :: 25;   // % chance for good treasure item
CURSED_CHANCE   :: 10;   // % of treasure being cursed
STAPLE_CHANCE   :: 20;   // % chance for staple item

// Count open tiles in a room
count_open_tiles_in_room :: (m: *GenMap, room: Room) -> s32 {
    count: s32 = 0;
    for y: room.bounds.y1..room.bounds.y2 {
        for x: room.bounds.x1..room.bounds.x2 {
            t := map_get(m, x, y);
            if t == .FLOOR || t == .CORRIDOR {
                count += 1;
            }
        }
    }
    return count;
}

// Find a valid position in a room for entity placement
// Source: Encounter.cpp:2537-2620 (monster placement rules)
find_open_in_room :: (m: *GenMap, room: Room, is_aquatic: bool = false, is_aerial: bool = false) -> s32, s32, bool {
    MAX_TRIES :: 50;
    room_w := rect_width(room.bounds);
    room_h := rect_height(room.bounds);
    if room_w <= 0 || room_h <= 0 return 0, 0, false;

    for try: 0..MAX_TRIES-1 {
        x := room.bounds.x1 + random(room_w);
        y := room.bounds.y1 + random(room_h);

        t := map_get(m, x, y);

        // Must be walkable terrain
        if t != .FLOOR && t != .CORRIDOR && t != .WATER && t != .RUBBLE continue;

        // Aquatic placement rules (Source: Encounter.cpp:2556-2265)
        if is_aquatic {
            // Aquatic creatures must be in water
            if t != .WATER continue;
        } else {
            // Non-aquatic creatures cannot be in water
            if t == .WATER continue;
        }

        // Fall terrain (chasm/lava) only for aerial creatures
        if t == .CHASM || t == .LAVA {
            if !is_aerial continue;
        }

        // Check no existing entity
        if has_monster_at(m, x, y) || has_item_at(m, x, y) continue;

        return x, y, true;
    }
    return 0, 0, false;
}

// Find a position for items (no aquatic/aerial restrictions)
find_open_for_item :: (m: *GenMap, room: Room) -> s32, s32, bool {
    MAX_TRIES :: 50;
    room_w := rect_width(room.bounds);
    room_h := rect_height(room.bounds);
    if room_w <= 0 || room_h <= 0 return 0, 0, false;

    for try: 0..MAX_TRIES-1 {
        x := room.bounds.x1 + random(room_w);
        y := room.bounds.y1 + random(room_h);

        t := map_get(m, x, y);
        if t != .FLOOR && t != .CORRIDOR && t != .RUBBLE continue;

        // Check no existing entity
        if has_monster_at(m, x, y) || has_item_at(m, x, y) continue;

        return x, y, true;
    }
    return 0, 0, false;
}

// Populate a single panel/room
// Source: MakeLev.cpp:3269-3301 (PopulatePanel)
populate_panel :: (m: *GenMap, room_index: s32, room: Room, depth_cr: s32, party_id: s32) -> s32, s32 {
    monsters_placed: s32 = 0;
    items_placed: s32 = 0;

    // Calculate monsters for this room based on open tile count
    open_count := count_open_tiles_in_room(m, room);
    if open_count == 0 return 0, 0;

    // Monster density: 1 per 30/50/75 tiles depending on depth
    divisor := monster_density_divisor(depth_cr);
    base_monster_count := max(1, open_count / divisor);

    // Apply CR cap
    max_monsters := max_monsters_by_cr(depth_cr);
    monster_count := min(base_monster_count, max_monsters);

    // Cap per room (don't overcrowd)
    monster_count = min(monster_count, 4);

    // Out-of-depth chance: 22% when depth > 1
    is_ood := depth_cr > 1 && random(100) < 22;

    // Check if room has water (for aquatic monster chance)
    has_water := false;
    for y: room.bounds.y1..room.bounds.y2 {
        for x: room.bounds.x1..room.bounds.x2 {
            if map_get(m, x, y) == .WATER {
                has_water = true;
                break y;
            }
        }
    }

    // Get resource database for monster lookups
    db := get_resource_db();

    // Place monsters in this room
    for i: 0..monster_count-1 {
        // Determine if this should be an aquatic monster
        // 20% chance if room has water, otherwise always land
        is_aquatic := has_water && random(100) < 20;
        is_aerial := random(100) < 5;  // 5% chance for aerial

        x, y, found := find_open_in_room(m, room, is_aquatic, is_aerial);
        if !found continue;

        mon: EntityPos;
        mon.x = x;
        mon.y = y;
        mon.room_index = room_index;
        mon.party_id = party_id;
        mon.is_aquatic = is_aquatic;
        mon.is_aerial = is_aerial;

        // CR: base or out-of-depth
        if is_ood {
            mon.cr = depth_cr + 1 + random(4);  // +1 to +4
        } else {
            mon.cr = depth_cr;
        }

        // Random sleep chance (higher at lower depths)
        sleep_threshold := random(100) + 1;
        mon.is_sleeping = sleep_threshold > 50;  // ~50% sleeping

        // Look up actual monster from resource database by CR
        rng_seed := random(cast(s32)0x7FFFFFFF);
        rmonster := find_monster_by_cr_fuzzy(db, mon.cr, 3, cast(u64)rng_seed);
        if rmonster != null {
            mon.glyph = rmonster.glyph;
            mon.fg_color = rmonster.fg_color;
            mon.type_id = cast(s32)(rmonster - db.monsters.data);  // Store index
        } else {
            // Fallback to generated glyph if no monster found
            mon.glyph, mon.fg_color = select_monster_glyph(mon.cr, is_aquatic, is_aerial);
        }

        array_add(*m.monsters, mon);
        monsters_placed += 1;
    }

    // Place items in room using proper distribution
    // Source: population.md lines 366-394

    // Chest chance
    if random(100) + 1 < CHEST_CHANCE {
        x, y, found := find_open_for_item(m, room);
        if found {
            item: EntityPos;
            item.x = x;
            item.y = y;
            item.room_index = room_index;
            item.cr = depth_cr;
            item.is_chest = true;
            // Chests always use chest glyph
            item.glyph = GLYPH_CHEST;
            item.fg_color = 6;  // Brown
            array_add(*m.items, item);
            items_placed += 1;
        }
    }
    // Treasure chance (if no chest)
    else if random(100) + 1 <= TREASURE_CHANCE {
        x, y, found := find_open_for_item(m, room);
        if found {
            item: EntityPos;
            item.x = x;
            item.y = y;
            item.room_index = room_index;
            item.cr = depth_cr + 3;  // Treasure is CR+3

            // Cursed chance
            if random(100) + 1 <= CURSED_CHANCE {
                item.is_cursed = true;
            } else {
                item.is_good = true;
            }
            // Look up actual item from resource database
            assign_item_from_db(db, *item);
            array_add(*m.items, item);
            items_placed += 1;
        }
    }
    // Poor item (50% chance if no chest/treasure)
    else if random(100) + 1 < 50 {
        x, y, found := find_open_for_item(m, room);
        if found {
            item: EntityPos;
            item.x = x;
            item.y = y;
            item.room_index = room_index;
            item.cr = cast(s32) max(0, depth_cr / 2 - 4);  // Lower tier
            assign_item_from_db(db, *item);
            array_add(*m.items, item);
            items_placed += 1;
        }
    }

    // Staple items
    if random(100) + 1 <= STAPLE_CHANCE {
        x, y, found := find_open_for_item(m, room);
        if found {
            item: EntityPos;
            item.x = x;
            item.y = y;
            item.room_index = room_index;
            item.cr = depth_cr;
            item.is_staple = true;
            // Staples use specific glyph types (potions, scrolls, food)
            item.glyph, item.fg_color = select_item_glyph(item.cr, false, true);
            array_add(*m.items, item);
            items_placed += 1;
        }
    }

    return monsters_placed, items_placed;
}

// Populate dungeon with monsters and items
// Source: MakeLev.cpp:3269-3301, Encounter.cpp:514-1125
// Uses per-panel population for better distribution
populate_dungeon :: (m: *GenMap, depth: s32) {
    // Calculate DepthCR
    depth_cr := depth;

    // Count total open tiles for stats
    total_open := count_open_tiles(m);
    if total_open == 0 return;

    total_monsters: s32 = 0;
    total_items: s32 = 0;

    // Generate unique party ID base for this level
    // Source: MakeLev.cpp:2900-2908
    // PartyID = MAX_PLAYERS + 10 + random(200)
    MAX_PLAYERS :: 6;
    base_party_id := MAX_PLAYERS + 10 + random(200);

    // Populate each room
    for room, room_index: m.rooms {
        // Each room gets its own party ID (creatures in same room don't fight)
        party_id := base_party_id + cast(s32)room_index;

        monsters, items := populate_panel(m, cast(s32)room_index, room, depth_cr, party_id);
        total_monsters += monsters;
        total_items += items;
    }

    if !makelev_quiet {
        print("  Populated level %: % monsters, % items (% open tiles)\n",
              depth, total_monsters, total_items, total_open);
    }
}

// Fix-up tunneling: ensure all regions are connected
// In original: "Step 5: Final, Fix-Up Tunneling" in Map::Generate
fixup_tunneling :: (m: *GenMap, gs: *GenState) {
    MAX_TRIALS :: 26;  // Same as original

    // Clear all connected flags
    clear_connected(gs, m);

    // Find first open tile and flood fill from there
    for y: 1..m.height-2 {
        for x: 1..m.width-2 {
            if !is_solid(gs, m, x, y) {
                flood_connect(gs, m, x, y);
                break y;  // Break both loops
            }
        }
    }

    // Try to connect unconnected regions
    for trial: 0..MAX_TRIALS-1 {
        // Find edge tiles of connected and unconnected regions
        connected_edges, unconnected_edges := find_disconnected_regions(gs, m);

        // If nothing is unconnected, we're done
        if unconnected_edges.count == 0 {
            break;
        }

        // Find the closest pair of connected <-> unconnected edge tiles
        best_dist: s32 = m.width * m.height;
        best_sx: s32 = -1;
        best_sy: s32 = -1;
        best_dx: s32 = -1;
        best_dy: s32 = -1;

        for c: connected_edges {
            for u: unconnected_edges {
                d := dist(c.x, c.y, u.x, u.y);
                if d < best_dist {
                    best_dist = d;
                    best_sx = c.x;
                    best_sy = c.y;
                    best_dx = u.x;
                    best_dy = u.y;
                }
            }
        }

        // Tunnel from connected to unconnected
        if best_sx >= 0 {
            carve_tunnel(m, gs, best_sx, best_sy, best_dx, best_dy, TT_DIRECT | TT_WANDER);

            // Re-flood to update connected status
            clear_connected(gs, m);
            for y: 1..m.height-2 {
                for x: 1..m.width-2 {
                    if !is_solid(gs, m, x, y) {
                        flood_connect(gs, m, x, y);
                        break y;
                    }
                }
            }
        } else {
            // No valid pair found
            break;
        }
    }
}

// ============================================================================
// Stair Placement
// Source: MakeLev.cpp:1706-1743 (up-stairs), 1879-1900 (down-stairs)
// ============================================================================

// Stair position for passing between levels
StairPos :: struct {
    x: s32;
    y: s32;
    room_index: s32;  // Which room this stair is in (-1 if not in a room)
}

// Find which room contains a position (returns -1 if none)
find_room_at :: (m: *GenMap, x: s32, y: s32) -> s32 {
    for room, idx: m.rooms {
        if rect_contains(room.bounds, x, y) {
            return cast(s32) idx;
        }
    }
    return -1;
}

// Place up-stairs at positions from level above's down-stairs
// Source: MakeLev.cpp:1706-1743
// If position is in solid rock, carve a 3x3 area around it
place_up_stairs :: (m: *GenMap, gs: *GenState, above_stairs: [] StairPos) -> stairs_placed: [..] StairPos {
    stairs_placed: [..] StairPos;

    for stair: above_stairs {
        x := stair.x;
        y := stair.y;

        // Check if position is valid
        if !map_in_bounds(m, x, y) continue;

        // If in solid rock, carve out space
        if is_solid(gs, m, x, y) {
            // Carve floor at stair position
            write_at(m, gs, x, y, gs.con.TERRAIN_FLOOR, PRIO_FEATURE_FLOOR, force = true);

            // Carve walls around it (3x3 area)
            for dy: s32.[-1, 0, 1] {
                for dx: s32.[-1, 0, 1] {
                    if dx == 0 && dy == 0 continue;
                    nx := x + dx;
                    ny := y + dy;
                    if map_in_bounds(m, nx, ny) && map_get(m, nx, ny) == .ROCK {
                        write_at(m, gs, nx, ny, gs.con.TERRAIN_WALL, PRIO_CORRIDOR_WALL);
                    }
                }
            }
        }

        // Place the up-stair
        map_set(m, x, y, .STAIRS_UP);

        // Track this stair
        placed: StairPos;
        placed.x = x;
        placed.y = y;
        placed.room_index = find_room_at(m, x, y);
        array_add(*stairs_placed, placed);
    }

    return stairs_placed;
}

// Check if a position is valid for down-stairs
// Source: MakeLev.cpp:1879-1900
is_valid_stair_pos :: (m: *GenMap, gs: *GenState, x: s32, y: s32, stairs_at: [] StairPos) -> bool {
    // Must be in bounds (not on edge)
    if x <= 0 || y <= 0 || x >= m.width - 1 || y >= m.height - 1 {
        return false;
    }

    // Must not be solid
    if is_solid(gs, m, x, y) {
        return false;
    }

    // Check priority - must be <= PRIO_ROOM_FLOOR
    cell := get_cell(gs, m, x, y);
    if cell != null && cell.priority > PRIO_ROOM_FLOOR {
        return false;
    }

    // Must not be water or chasm (fall terrain)
    t := map_get(m, x, y);
    if t == .WATER || t == .CHASM || t == .LAVA {
        return false;
    }

    // Must not already have a stair
    if t == .STAIRS_UP || t == .STAIRS_DOWN {
        return false;
    }

    // Check if this room already has stairs
    room_idx := find_room_at(m, x, y);
    if room_idx >= 0 {
        for stair: stairs_at {
            if stair.room_index == room_idx {
                return false;  // This room already has a stair
            }
        }
    }

    return true;
}

// Place down-stairs (MIN_STAIRS to MAX_STAIRS)
// Source: MakeLev.cpp:1879-1900
// Returns positions for next level's up-stairs
place_down_stairs :: (m: *GenMap, gs: *GenState, up_stairs: [] StairPos, depth: s32, max_depth: s32) -> down_stairs: [..] StairPos {
    down_stairs: [..] StairPos;

    // Don't place down-stairs on the last level
    if depth >= max_depth {
        return down_stairs;
    }

    // Determine number of stairs to place
    min_stairs := gs.con.MIN_STAIRS;
    max_stairs := gs.con.MAX_STAIRS;
    num_stairs := min_stairs + random(max_stairs - min_stairs + 1);

    // Combine up_stairs into our tracking array for room avoidance
    all_stairs: [..] StairPos;
    all_stairs.allocator = temp;
    for s: up_stairs {
        array_add(*all_stairs, s);
    }

    // Place each stair
    MAX_TRIES :: 500;

    for i: 0..num_stairs-1 {
        placed := false;

        for try: 0..MAX_TRIES-1 {
            // Random position
            x := 1 + random(m.width - 2);
            y := 1 + random(m.height - 2);

            // Check if valid (including room avoidance)
            if is_valid_stair_pos(m, gs, x, y, all_stairs) {
                // Place the stair
                map_set(m, x, y, .STAIRS_DOWN);

                // Track it
                stair: StairPos;
                stair.x = x;
                stair.y = y;
                stair.room_index = find_room_at(m, x, y);
                array_add(*down_stairs, stair);
                array_add(*all_stairs, stair);

                placed = true;
                break;
            }
        }

        // If we couldn't place after MAX_TRIES, skip this stair (graceful degradation)
        if !placed {
            // This is expected behavior per spec - dungeon may have fewer stairs than intended
        }
    }

    return down_stairs;
}

// Main generation function - matches Map::Generate structure
// Extended to support multi-level generation with stair continuity
generate_makelev :: (m: *GenMap, seed: u32, above_down_stairs: [] StairPos = .[], depth: s32 = 1, max_depth: s32 = 10) -> down_stairs: [..] StairPos {
    // Initialize RNG
    random_init(seed);

    // Initialize map
    map_init(m);
    m.depth = depth;

    // Initialize generation state
    gs: GenState;
    gen_state_init(*gs, depth = depth);

    // Step 1: Fill with rock, edges with wall
    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            if x == 0 || y == 0 || x == m.width-1 || y == m.height-1 {
                map_set(m, x, y, .WALL);
                cell := get_cell(*gs, m, x, y);
                if cell != null {
                    cell.priority = PRIO_MAX;
                    cell.solid = true;
                }
            } else {
                map_set(m, x, y, .ROCK);
                cell := get_cell(*gs, m, x, y);
                if cell != null {
                    cell.priority = PRIO_EMPTY;
                    cell.solid = true;
                }
            }
        }
    }

    // Step 2: Place streamers (rivers, chasms)
    // Original algorithm (MakeLev.cpp:1419-1464):
    //   Generate MIN_STREAMERS guaranteed, then STREAMER_CHANCE% each additional up to MAX_STREAMERS.
    //   50% chance to reuse previous streamer type. Depth restrictions for rivers/chasms.
    {
        streamers_placed : s32 = 0;
        last_stype: StreamerType;
        has_last_stype := false;

        while streamers_placed < gs.con.MIN_STREAMERS ||
              (random(100) < gs.con.STREAMER_CHANCE && streamers_placed < gs.con.MAX_STREAMERS) {

            // 50% chance to reuse previous streamer type (original: random(10) > 5)
            reuse := has_last_stype && random(10) > 5;
            stype: StreamerType;

            if reuse {
                stype = last_stype;
            } else {
                // Weighted random selection with depth restrictions (up to 20 tries)
                found := false;
                for try_i: 0..19 {
                    streamer_roll := random(100);

                    if streamer_roll < 35 {
                        stype = .WATER_RIVER;
                    } else if streamer_roll < 55 {
                        stype = .CHASM;
                    } else if streamer_roll < 75 {
                        stype = .WATER_STREAM;
                    } else if streamer_roll < 90 {
                        stype = .LAVA_RIVER;
                    } else {
                        stype = .RUBBLE;
                    }

                    // Depth restrictions (original MakeLev.cpp:1446-1456)
                    if stype == .WATER_RIVER || stype == .LAVA_RIVER {
                        if m.depth < gs.con.MIN_RIVER_DEPTH  continue;
                    }
                    if stype == .CHASM {
                        if m.depth < gs.con.MIN_CHASM_DEPTH  continue;
                        // No chasms on last level (nowhere to fall)
                        if m.depth == gs.con.DUN_DEPTH  continue;
                    }

                    found = true;
                    break;
                }
                if !found  break;  // Couldn't find valid type after 20 tries
            }

            // Place the streamer at random position
            write_streamer(m, *gs, stype);
            last_stype = stype;
            has_last_stype = true;
            streamers_placed += 1;
        }
    }

    // Step 3: Place vaults (special pre-designed rooms)
    // 20% chance per level, higher at deeper levels
    vault_chance := 20 + m.depth * 5;
    if random(100) < vault_chance {
        if try_place_vault(m, *gs, m.depth) {
            if !makelev_quiet print("  Placed vault on level %\n", m.depth);
        }
    }

    // Step 4: Draw each panel
    for py: 0..gs.panels_y-1 {
        for px: 0..gs.panels_x-1 {
            if !(gs.panels_drawn[py] & cast(u32)(1 << px)) {
                draw_panel(m, *gs, px, py);
            }
        }
    }

    // Step 5: Connect panels with corridors
    connect_panels(m, *gs);

    // Step 5.5: Fix-up tunneling - ensure all regions are connected
    // This is critical for playable dungeons!
    fixup_tunneling(m, *gs);

    // Step 5.6: Furnish rooms with pillars, rubble, etc.
    // Source: MakeLev.cpp:2951-3266 (FurnishArea)
    for room: m.rooms {
        furnish_room(m, room);
    }

    // Step 5.7: Place torches and calculate lighting
    // Source: MakeLev.cpp ROOM_LIT_CHANCE, TORCH_DENSITY
    place_room_lights(m, *gs, depth);

    // Step 6: Place doors where corridors meet rooms
    // Per spec: 10% open, ~45% locked, ~45% unlocked, ~14% secret
    place_doors_makelev(m, depth);

    // Step 6b: Place traps at doors and bottlenecks
    // Source: MakeLev.cpp:2155-2192
    place_traps(m, depth);

    // Step 6c: Place treasure deposits in solid rock
    // Per spec: count = 1d4 + Depth, hidden in fully-enclosed rock
    place_treasure_deposits(m, depth);

    // Step 7: Place stairs
    // Source: MakeLev.cpp:1706-1743 (up), 1879-1900 (down)

    // Place up-stairs at positions from level above
    up_stairs := place_up_stairs(m, *gs, above_down_stairs);

    // Place down-stairs (MIN_STAIRS to MAX_STAIRS)
    down_stairs := place_down_stairs(m, *gs, up_stairs, depth, max_depth);

    // If no stairs were placed at all (empty dungeon?), place at least one of each in rooms
    if up_stairs.count == 0 && above_down_stairs.count == 0 && m.rooms.count >= 1 {
        // First level with no above - place up-stair in first room
        first_room := m.rooms[0];
        cx, cy := rect_center(first_room.bounds);
        if !is_solid(*gs, m, cx, cy) {
            map_set(m, cx, cy, .STAIRS_UP);
        }
    }

    if down_stairs.count == 0 && depth < max_depth && m.rooms.count >= 1 {
        // Failed to place any down-stairs - try room centers as fallback
        for room, idx: m.rooms {
            cx, cy := rect_center(room.bounds);
            empty_stairs: [0] StairPos;
            if is_valid_stair_pos(m, *gs, cx, cy, empty_stairs) {
                map_set(m, cx, cy, .STAIRS_DOWN);
                stair: StairPos;
                stair.x = cx;
                stair.y = cy;
                stair.room_index = cast(s32) idx;
                array_add(*down_stairs, stair);
                break;  // Just need one
            }
        }
    }

    // Step 8: Populate dungeon with monsters and items
    // Source: MakeLev.cpp:3269-3301, Encounter.cpp:514-1125
    populate_dungeon(m, depth);

    if !makelev_quiet {
        print("Generated dungeon (ORIGINAL MakeLev) depth % with % rooms, % up-stairs, % down-stairs, % monsters, % items\n",
              depth, m.rooms.count, up_stairs.count, down_stairs.count, m.monsters.count, m.items.count);
    }

    return down_stairs;
}

// ============================================================================
// Glyph Selection for Entities
// ============================================================================

// Select a monster glyph and color based on CR and environment
// This provides visual variety until full resource database lookup is implemented
select_monster_glyph :: (cr: s32, is_aquatic: bool, is_aerial: bool) -> u16, u8 {
    // Aquatic monsters
    if is_aquatic {
        if cr <= 2 {
            return #char "f", 9;   // Fish, bright blue
        } else if cr <= 5 {
            return #char "S", 9;   // Sea serpent, bright blue
        } else {
            return #char "K", 11;  // Kraken, bright cyan
        }
    }

    // Aerial monsters
    if is_aerial {
        if cr <= 2 {
            return #char "B", 6;   // Bat, brown
        } else if cr <= 5 {
            return #char "E", 7;   // Eye/beholder-like, grey
        } else {
            return #char "W", 15;  // Wraith/phantom, white
        }
    }

    // Land creatures by CR tier
    if cr <= 1 {
        // Low level: vermin, small animals
        choices :: u16.[#char "r", #char "k", #char "g", #char "s"];
        colors  :: u8.[6, 2, 2, 10];  // brown, green, green, bright green
        idx := cast(s32)(random(cast(s32)choices.count));
        return choices[idx], colors[idx];
    } else if cr <= 3 {
        // Goblins, orcs, wolves
        choices :: u16.[#char "o", #char "g", #char "h", #char "w"];
        colors  :: u8.[2, 10, 6, 7];  // green, bright green, brown, grey
        idx := cast(s32)(random(cast(s32)choices.count));
        return choices[idx], colors[idx];
    } else if cr <= 6 {
        // Trolls, ogres, gnolls
        choices :: u16.[#char "T", #char "O", #char "G", #char "H"];
        colors  :: u8.[2, 6, 6, 12];  // green, brown, brown, bright red
        idx := cast(s32)(random(cast(s32)choices.count));
        return choices[idx], colors[idx];
    } else if cr <= 10 {
        // Giants, demons, powerful undead
        choices :: u16.[#char "D", #char "&", #char "V", #char "L"];
        colors  :: u8.[12, 12, 13, 13];  // bright red, bright red, magenta, magenta
        idx := cast(s32)(random(cast(s32)choices.count));
        return choices[idx], colors[idx];
    } else {
        // Ancient/epic creatures
        choices :: u16.[#char "D", #char "&", #char "A", #char "@"];
        colors  :: u8.[14, 14, 15, 13];  // yellow, yellow, white, magenta
        idx := cast(s32)(random(cast(s32)choices.count));
        return choices[idx], colors[idx];
    }
}

// Select an item glyph and color based on type and tier
select_item_glyph :: (cr: s32, is_chest: bool, is_staple: bool) -> u16, u8 {
    // Chests always use chest glyph
    if is_chest {
        return GLYPH_CHEST, 6;  // Brown
    }

    // Staple items (consumables) - potions, scrolls, food
    if is_staple {
        choices :: u16.[GLYPH_POTION, GLYPH_SCROLL, GLYPH_FOOD, GLYPH_HERB];
        colors  :: u8.[9, 15, 6, 10];  // bright blue, white, brown, bright green
        idx := cast(s32)(random(cast(s32)choices.count));
        return choices[idx], colors[idx];
    }

    // Regular items by CR tier
    if cr <= 2 {
        // Low tier: simple weapons, basic armor, coins
        choices :: u16.[GLYPH_WEAPON, GLYPH_SWORD, GLYPH_COIN, GLYPH_LARMOUR];
        colors  :: u8.[7, 7, 14, 6];  // grey, grey, yellow, brown
        idx := cast(s32)(random(cast(s32)choices.count));
        return choices[idx], colors[idx];
    } else if cr <= 5 {
        // Mid tier: better equipment
        choices :: u16.[GLYPH_SWORD, GLYPH_MARMOUR, GLYPH_SHIELD, GLYPH_RING];
        colors  :: u8.[15, 7, 7, 14];  // white, grey, grey, yellow
        idx := cast(s32)(random(cast(s32)choices.count));
        return choices[idx], colors[idx];
    } else if cr <= 8 {
        // High tier: magical items
        choices :: u16.[GLYPH_WAND, GLYPH_STAFF, GLYPH_RING, GLYPH_AMULET];
        colors  :: u8.[9, 6, 14, 13];  // bright blue, brown, yellow, magenta
        idx := cast(s32)(random(cast(s32)choices.count));
        return choices[idx], colors[idx];
    } else {
        // Epic tier: rare artifacts
        choices :: u16.[GLYPH_CROWN, GLYPH_GEM, GLYPH_BOOK, GLYPH_FIGURE];
        colors  :: u8.[14, 11, 13, 15];  // yellow, cyan, magenta, white
        idx := cast(s32)(random(cast(s32)choices.count));
        return choices[idx], colors[idx];
    }
}

// Assign item glyph/color from resource database
// Uses item.cr as the target level, with fuzzy matching
assign_item_from_db :: (db: *ResourceDB, item: *EntityPos) {
    rng_seed := random(cast(s32)0x7FFFFFFF);
    ritem := find_item_by_level_fuzzy(db, item.cr, 5, cast(u64)rng_seed);
    if ritem != null {
        item.glyph = ritem.glyph;
        item.fg_color = ritem.fg_color;
        item.type_id = cast(s32)(ritem - db.items.data);  // Store index
    } else {
        // Fallback to generated glyph
        item.glyph, item.fg_color = select_item_glyph(item.cr, false, false);
    }
}
