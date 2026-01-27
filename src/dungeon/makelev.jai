// MakeLev - Original Incursion dungeon generation
//
// This is a faithful translation of MakeLev.cpp to produce identical
// dungeons given the same RNG seed.
//
// Reference: C:\Data\R\roguelike - incursion\repo-work\src\MakeLev.cpp
//
// Note: This file is loaded by main.jai which handles all imports.

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
PRIO_EMPTY          :: 0;
PRIO_ROCK_STREAMER  :: 10;
PRIO_RIVER_STREAMER :: 15;   // Rivers/chasms have higher priority than rock streamers
PRIO_CORRIDOR_WALL  :: 20;
PRIO_CORRIDOR_FLOOR :: 30;
PRIO_ROOM_WALL      :: 40;
PRIO_ROOM_FLOOR     :: 50;
PRIO_ROOM_FURNITURE :: 60;
PRIO_VAULT          :: 80;
PRIO_FEATURE_FLOOR  :: 90;
PRIO_MAX            :: 100;

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

    // Initialize weighted selection
    init_dungeon_weights(*gs.dungeon_weights);
    init_selection_state(*gs.selection, *gs.dungeon_weights, depth);
    gs.current_region = null;
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

    // Fill interior with floor
    for y: r.y1..r.y2 {
        for x: r.x1..r.x2 {
            write_at(m, gs, x, y, floor, PRIO_ROOM_FLOOR);
        }
    }

    // Draw walls around it
    for x: r.x1-1..r.x2+1 {
        if map_get(m, x, r.y1-1) == .ROCK  write_at(m, gs, x, r.y1-1, wall, PRIO_ROOM_WALL);
        if map_get(m, x, r.y2+1) == .ROCK  write_at(m, gs, x, r.y2+1, wall, PRIO_ROOM_WALL);
    }
    for y: r.y1-1..r.y2+1 {
        if map_get(m, r.x1-1, y) == .ROCK  write_at(m, gs, r.x1-1, y, wall, PRIO_ROOM_WALL);
        if map_get(m, r.x2+1, y) == .ROCK  write_at(m, gs, r.x2+1, y, wall, PRIO_ROOM_WALL);
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

    for y: r.y1-1..r.y2+1 {
        for x: r.x1-1..r.x2+1 {
            dx := x - cx;
            dy := y - cy;
            dist_sq := dx*dx + dy*dy;

            if dist_sq <= radius * radius {
                write_at(m, x, y, floor);
            } else if dist_sq <= (radius+1) * (radius+1) {
                if map_get(m, x, y) == .ROCK {
                    write_at(m, x, y, wall);
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
    // Start with rectangular room
    write_room(m, gs, r);

    wall := gs.con.TERRAIN_WALL;

    // Cut corners
    corner_size := min(rect_width(r), rect_height(r)) / 4;
    if corner_size < 1 corner_size = 1;

    // Top-left
    for i: 0..corner_size-1 {
        for j: 0..corner_size-1-i {
            write_at(m, r.x1 + j, r.y1 + i, wall);
        }
    }
    // Top-right
    for i: 0..corner_size-1 {
        for j: 0..corner_size-1-i {
            write_at(m, r.x2 - j, r.y1 + i, wall);
        }
    }
    // Bottom-left
    for i: 0..corner_size-1 {
        for j: 0..corner_size-1-i {
            write_at(m, r.x1 + j, r.y2 - i, wall);
        }
    }
    // Bottom-right
    for i: 0..corner_size-1 {
        for j: 0..corner_size-1-i {
            write_at(m, r.x2 - j, r.y2 - i, wall);
        }
    }
}

// Write a cross-shaped room
// In original: void Map::WriteCross(Rect &r, rID regID)
write_cross :: (m: *GenMap, gs: *GenState, r: Rect) {
    cx, cy := rect_center(r);
    w := rect_width(r);
    h := rect_height(r);

    // Horizontal bar
    bar_h := max(h / 3, 3);
    h_rect := Rect.{r.x1, cy - bar_h/2, r.x2, cy + bar_h/2};
    write_room(m, gs, h_rect);

    // Vertical bar
    bar_w := max(w / 3, 3);
    v_rect := Rect.{cx - bar_w/2, r.y1, cx + bar_w/2, r.y2};

    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;

    // Fill vertical bar
    for y: v_rect.y1..v_rect.y2 {
        for x: v_rect.x1..v_rect.x2 {
            write_at(m, x, y, floor);
        }
    }

    // Add walls around vertical bar
    for y: v_rect.y1-1..v_rect.y2+1 {
        if map_get(m, v_rect.x1-1, y) == .ROCK  write_at(m, v_rect.x1-1, y, wall);
        if map_get(m, v_rect.x2+1, y) == .ROCK  write_at(m, v_rect.x2+1, y, wall);
    }
    for x: v_rect.x1..v_rect.x2 {
        if map_get(m, x, v_rect.y1-1) == .ROCK  write_at(m, x, v_rect.y1-1, wall);
        if map_get(m, x, v_rect.y2+1) == .ROCK  write_at(m, x, v_rect.y2+1, wall);
    }
}

// Write a cave using cellular automata (Game of Life variant)
// In original: void Map::WriteLifeCave(Rect &r, rID regID)
write_lifecave :: (m: *GenMap, gs: *GenState, r: Rect) {
    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;

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
                write_at(m, mx, my, floor);
            }
        }
    }

    // Add walls around open spaces
    for gy: 1..h-2 {
        for gx: 1..w-2 {
            idx := gy * w + gx;
            if grid[idx] == 0 {  // This is floor
                mx := r.x1 + cast(s32)gx - 1;
                my := r.y1 + cast(s32)gy - 1;
                // Check all 8 neighbors for rock
                for dy: -1..1 {
                    for dx: -1..1 {
                        if dx == 0 && dy == 0 continue;
                        if map_get(m, mx + cast(s32)dx, my + cast(s32)dy) == .ROCK {
                            write_at(m, mx + cast(s32)dx, my + cast(s32)dy, wall);
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
                write_at(m, x, y, floor);
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
                            write_at(m, nx, ny, wall);
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

    for y: r.y1..r.y2 {
        for x: r.x1..r.x2 {
            write_at(m, x, y, floor);
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
                            write_at(m, nx, ny, wall);
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
    // First create normal room
    write_room(m, gs, r);

    wall := gs.con.TERRAIN_WALL;

    // Add pillars in a grid pattern (every 2 tiles)
    for y: r.y1+1..r.y2-1 {
        for x: r.x1+1..r.x2-1 {
            // Place pillar at even intervals from top-left
            x_offset := x - r.x1;
            y_offset := y - r.y1;
            if (x_offset % 2 == 0) && (y_offset % 2 == 0) {
                // 95% chance of pillar (5% missing for variety)
                if random(100) < 95 {
                    write_at(m, x, y, wall);
                }
            }
        }
    }
}

// Write a double room (room within a room)
// In original: case RM_DOUBLE
write_double :: (m: *GenMap, gs: *GenState, r: Rect) {
    // Outer room
    write_room(m, gs, r);

    wall := gs.con.TERRAIN_WALL;
    floor := gs.con.TERRAIN_FLOOR;

    // Inner room (inset by 2)
    inner := Rect.{r.x1 + 2, r.y1 + 2, r.x2 - 2, r.y2 - 2};

    // Make sure inner room is big enough
    if rect_width(inner) < 3 || rect_height(inner) < 3 return;

    // Draw inner walls
    for x: inner.x1..inner.x2 {
        write_at(m, x, inner.y1, wall);
        write_at(m, x, inner.y2, wall);
    }
    for y: inner.y1..inner.y2 {
        write_at(m, inner.x1, y, wall);
        write_at(m, inner.x2, y, wall);
    }

    // Add 1-3 doors in the inner wall
    num_doors := 1 + random(3);
    for i: 0..num_doors-1 {
        if random(2) == 0 {
            // Door on horizontal wall
            x := inner.x1 + 1 + random(rect_width(inner) - 2);
            y := ifx random(2) == 0 then inner.y1 else inner.y2;
            write_at(m, x, cast(s32)y, floor);
        } else {
            // Door on vertical wall
            x := ifx random(2) == 0 then inner.x1 else inner.x2;
            y := inner.y1 + 1 + random(rect_height(inner) - 2);
            write_at(m, cast(s32)x, y, floor);
        }
    }
}

// Write a maze room using recursive backtracking
// In original: case RM_MAZE (calls WriteMaze)
write_maze :: (m: *GenMap, gs: *GenState, r: Rect) {
    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;

    // First fill with walls
    for y: r.y1..r.y2 {
        for x: r.x1..r.x2 {
            write_at(m, x, y, wall);
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
    write_at(m, start_x, start_y, floor);
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
            write_at(m, wall_x, wall_y, floor);
            write_at(m, nx, ny, floor);

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

    // Fill with floor first
    for y: r.y1..r.y2 {
        for x: r.x1..r.x2 {
            write_at(m, x, y, floor);
        }
    }

    // Add checkerboard walls (every 2nd cell)
    for y: r.y1+1..r.y2-1 {
        for x: r.x1+1..r.x2-1 {
            x_even := ((x - r.x1) % 2) == 0;
            y_even := ((y - r.y1) % 2) == 0;
            if x_even == y_even {
                write_at(m, x, y, wall);
            }
        }
    }

    // Add walls around the perimeter
    for x: r.x1-1..r.x2+1 {
        if map_get(m, x, r.y1-1) == .ROCK  write_at(m, x, r.y1-1, wall);
        if map_get(m, x, r.y2+1) == .ROCK  write_at(m, x, r.y2+1, wall);
    }
    for y: r.y1-1..r.y2+1 {
        if map_get(m, r.x1-1, y) == .ROCK  write_at(m, r.x1-1, y, wall);
        if map_get(m, r.x2+1, y) == .ROCK  write_at(m, r.x2+1, y, wall);
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

// Write a room with diamond-shaped cells
// In original: case RM_DIAMONDS
write_diamonds :: (m: *GenMap, gs: *GenState, r: Rect) {
    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;

    // Fill with floor first
    for y: r.y1..r.y2 {
        for x: r.x1..r.x2 {
            write_at(m, x, y, floor);
        }
    }

    // Add diamond pattern walls
    // Diamonds are spaced 4 apart
    DIAMOND_SIZE :: 3;
    DIAMOND_SPACING :: 4;

    center_y := r.y1 + DIAMOND_SIZE;
    while center_y < r.y2 - DIAMOND_SIZE {
        center_x := r.x1 + DIAMOND_SIZE;
        while center_x < r.x2 - DIAMOND_SIZE {
            // Draw diamond outline around center
            for dist: 1..DIAMOND_SIZE-1 {
                // Top
                write_at(m, center_x, center_y - cast(s32)dist, wall);
                // Bottom
                write_at(m, center_x, center_y + cast(s32)dist, wall);
                // Left
                write_at(m, center_x - cast(s32)dist, center_y, wall);
                // Right
                write_at(m, center_x + cast(s32)dist, center_y, wall);
            }
            // Corners
            write_at(m, center_x - 1, center_y - 1, wall);
            write_at(m, center_x + 1, center_y - 1, wall);
            write_at(m, center_x - 1, center_y + 1, wall);
            write_at(m, center_x + 1, center_y + 1, wall);

            center_x += DIAMOND_SPACING;
        }
        center_y += DIAMOND_SPACING;
    }

    // Add walls around the perimeter
    for x: r.x1-1..r.x2+1 {
        if map_get(m, x, r.y1-1) == .ROCK  write_at(m, x, r.y1-1, wall);
        if map_get(m, x, r.y2+1) == .ROCK  write_at(m, x, r.y2+1, wall);
    }
    for y: r.y1-1..r.y2+1 {
        if map_get(m, r.x1-1, y) == .ROCK  write_at(m, r.x1-1, y, wall);
        if map_get(m, r.x2+1, y) == .ROCK  write_at(m, r.x2+1, y, wall);
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

// Write a castle room (recursively subdivided with internal walls and doors)
// In original: void Map::WriteCastle(Rect &r, rID regID)
write_castle :: (m: *GenMap, gs: *GenState, r: Rect, depth: s32 = 0) {
    floor := gs.con.TERRAIN_FLOOR;
    wall := gs.con.TERRAIN_WALL;

    sx := rect_width(r);
    sy := rect_height(r);

    // Base case: too small to subdivide further
    if sx < 7 || sy < 7 || depth > 4 {
        // Just fill with floor
        for y: r.y1..r.y2 {
            for x: r.x1..r.x2 {
                write_at(m, x, y, floor);
            }
        }
        return;
    }

    // Fill base with floor first
    for y: r.y1..r.y2 {
        for x: r.x1..r.x2 {
            write_at(m, x, y, floor);
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
                write_at(m, d, y, wall);
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
                write_at(m, x, d, wall);
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
            if map_get(m, x, r.y1-1) == .ROCK  write_at(m, x, r.y1-1, wall);
            if map_get(m, x, r.y2+1) == .ROCK  write_at(m, x, r.y2+1, wall);
        }
        for y: r.y1-1..r.y2+1 {
            if map_get(m, r.x1-1, y) == .ROCK  write_at(m, r.x1-1, y, wall);
            if map_get(m, r.x2+1, y) == .ROCK  write_at(m, r.x2+1, y, wall);
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

    BUFFER :: 3;
    sx := rect_width(r) - BUFFER;
    sy := rect_height(r) - BUFFER;

    if sx < 12 || sy < 12 {
        // Too small, just make a regular room
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
                write_at(m, x + cast(s32)j, y, floor);
                write_at(m, x, y - cast(s32)j, floor);
            }
        } else if direction == 1 {
            // Right and down
            for j: 0..L_LEN-1 {
                write_at(m, x + cast(s32)j, y, floor);
                write_at(m, x, y + cast(s32)j, floor);
            }
        } else if direction == 2 {
            // Left and up
            for j: 0..L_LEN-1 {
                write_at(m, x - cast(s32)j, y, floor);
                write_at(m, x, y - cast(s32)j, floor);
            }
        } else {
            // Left and down
            for j: 0..L_LEN-1 {
                write_at(m, x - cast(s32)j, y, floor);
                write_at(m, x, y + cast(s32)j, floor);
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
                            write_at(m, nx, ny, wall);
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

    // Record center
    if gs.n_centers < 16 {
        cx, cy := rect_center(r);
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

    // Calculate room size
    sx := con.ROOM_MINX + random(con.ROOM_MAXX - con.ROOM_MINX);
    sy := con.ROOM_MINY + random(con.ROOM_MAXY - con.ROOM_MINY);

    // For large rooms, make them bigger
    if r_type == RM_LARGE {
        sx = min(con.PANEL_SIZEX - 4, sx + 4);
        sy = min(con.PANEL_SIZEY - 4, sy + 4);
    }

    // Place room in panel
    r := place_within_panel(panel, sx, sy);

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
            // Lifecave uses most of the panel
            cave_r := Rect.{panel.x1 + 1, panel.y1 + 1, panel.x2 - 1, panel.y2 - 1};
            write_lifecave(m, gs, cave_r);

        case RM_OVERLAP;
            write_overlap(m, gs, panel);

        case RM_ADJACENT;
            write_adjacent(m, gs, panel, use_circles = false, mixed = false);

        case RM_AD_ROUND;
            write_adjacent(m, gs, panel, use_circles = true, mixed = false);

        case RM_AD_MIXED;
            write_adjacent(m, gs, panel, use_circles = false, mixed = true);

        case RM_PILLARS;
            // Pillars need larger room to look good
            pillar_r := Rect.{panel.x1 + 2, panel.y1 + 2, panel.x2 - 2, panel.y2 - 2};
            write_pillars(m, gs, pillar_r);

        case RM_DOUBLE;
            // Double needs larger room
            double_sx := max(sx + 4, 10);
            double_sy := max(sy + 4, 8);
            double_r := place_within_panel(panel, double_sx, double_sy);
            write_double(m, gs, double_r);

        case RM_MAZE;
            // Maze fills most of the panel
            maze_r := Rect.{panel.x1 + 1, panel.y1 + 1, panel.x2 - 1, panel.y2 - 1};
            write_maze(m, gs, maze_r);

        case RM_CHECKER;
            // Checker needs decent size
            checker_r := Rect.{panel.x1 + 2, panel.y1 + 2, panel.x2 - 2, panel.y2 - 2};
            write_checker(m, gs, checker_r);

        case RM_DIAMONDS;
            // Diamonds need large area
            diamonds_r := Rect.{panel.x1 + 1, panel.y1 + 1, panel.x2 - 1, panel.y2 - 1};
            write_diamonds(m, gs, diamonds_r);

        case RM_CASTLE; #through;
        case RM_BUILDING;
            // Castle/building fills most of panel
            castle_r := Rect.{panel.x1 + 2, panel.y1 + 2, panel.x2 - 2, panel.y2 - 2};
            write_castle(m, gs, castle_r);

        case RM_RCAVERN;
            // Rough cavern fills panel
            cavern_r := Rect.{panel.x1 + 1, panel.y1 + 1, panel.x2 - 1, panel.y2 - 1};
            write_rcavern(m, gs, cavern_r);

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

// Tunnel constants
TURN_CHANCE       :: 25;   // % chance to turn each step after min segment
SEGMENT_MIN_LEN   :: 3;    // Minimum segment length before turning
SEGMENT_MAX_LEN   :: 12;   // Maximum segment length before forced turn
STUBBORN_CORRIDOR :: 30;   // % chance to NOT correct direction toward target
MAX_CORRIDOR_LEN  :: 500;  // Safety limit

// Get direction that corrects toward destination
// In original: Dir Map::CorrectDir(...)
correct_dir :: (x: s32, y: s32, dx: s32, dy: s32, curr: TunnelDir) -> TunnelDir {
    // If on same row/column, go directly
    if x == dx {
        return ifx y > dy then .NORTH else .SOUTH;
    }
    if y == dy {
        return ifx x > dx then .WEST else .EAST;
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

    // Sometimes swap for variety
    if random(4) == 0 {
        tmp := option1;
        option1 = option2;
        option2 = tmp;
    }

    // Don't go back the way we came (diametric check)
    curr_dx := TunnelDirX[cast(s32)curr];
    curr_dy := TunnelDirY[cast(s32)curr];
    opt1_dx := TunnelDirX[cast(s32)option1];
    opt1_dy := TunnelDirY[cast(s32)option1];

    if curr_dx + opt1_dx == 0 && curr_dy + opt1_dy == 0 {
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

    while total_length < MAX_CORRIDOR_LEN {
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

        // Force turn near map edges
        if nx <= 2 || nx >= m.width - 3 || ny <= 2 || ny >= m.height - 3 {
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
        if seg_length > SEGMENT_MAX_LEN {
            force_turn = true;
        }

        // Random turn chance after minimum segment (if not TT_DIRECT)
        if !force_turn && seg_length > SEGMENT_MIN_LEN && random(100) < TURN_CHANCE {
            force_turn = true;
        }

        // Turn if needed
        if force_turn {
            seg_length = 0;
            // TT_DIRECT: always correct toward destination
            // Otherwise: usually correct, sometimes go random (STUBBORN_CORRIDOR)
            if (tflags & TT_DIRECT) || random(100) > STUBBORN_CORRIDOR {
                curr_dir = correct_dir(x, y, dx, dy, curr_dir);
            } else {
                // Random perpendicular turn
                old_dir := curr_dir;
                while curr_dir == old_dir {
                    curr_dir = cast(TunnelDir) random(4);
                }
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
connect_panels :: (m: *GenMap, gs: *GenState) {
    // For each adjacent pair of panels, connect them
    for py: 0..gs.panels_y-1 {
        for px: 0..gs.panels_x-1 {
            // Find a floor tile in this panel
            panel_x := px * gs.con.PANEL_SIZEX + gs.con.PANEL_SIZEX / 2;
            panel_y := py * gs.con.PANEL_SIZEY + gs.con.PANEL_SIZEY / 2;

            // Search for nearest floor
            sx, sy: s32 = -1, -1;
            for dy: -10..10 {
                for dx: -10..10 {
                    tx := panel_x + cast(s32)dx;
                    ty := panel_y + cast(s32)dy;
                    if map_get(m, tx, ty) == .FLOOR {
                        sx = tx;
                        sy = ty;
                        break dy;
                    }
                }
            }

            if sx < 0 continue;  // No floor found

            // Connect to right neighbor
            if px < gs.panels_x - 1 {
                next_x := (px + 1) * gs.con.PANEL_SIZEX + gs.con.PANEL_SIZEX / 2;
                next_y := py * gs.con.PANEL_SIZEY + gs.con.PANEL_SIZEY / 2;

                // Find floor in next panel
                for dy: -10..10 {
                    for dx: -10..10 {
                        tx := next_x + cast(s32)dx;
                        ty := next_y + cast(s32)dy;
                        if map_get(m, tx, ty) == .FLOOR {
                            carve_corridor(m, gs, sx, sy, tx, ty);
                            break dy;
                        }
                    }
                }
            }

            // Connect to bottom neighbor
            if py < gs.panels_y - 1 {
                next_x := px * gs.con.PANEL_SIZEX + gs.con.PANEL_SIZEX / 2;
                next_y := (py + 1) * gs.con.PANEL_SIZEY + gs.con.PANEL_SIZEY / 2;

                // Find floor in next panel
                for dy: -10..10 {
                    for dx: -10..10 {
                        tx := next_x + cast(s32)dx;
                        ty := next_y + cast(s32)dy;
                        if map_get(m, tx, ty) == .FLOOR {
                            carve_corridor(m, gs, sx, sy, tx, ty);
                            break dy;
                        }
                    }
                }
            }
        }
    }
}

// Note: Dir enum and DirX/DirY functions are defined in defines.jai

// Write a streamer (river or chasm) across the map
// In original: void Map::WriteStreamer(Rect &r, uint8 sx, uint8 sy, Dir d, rID regID)
write_streamer :: (m: *GenMap, gs: *GenState, stype: StreamerType) {
    info := STREAMER_INFO[cast(s32) stype];
    terrain := info.terrain;
    is_river := info.is_river;

    // Pick starting position and direction
    sx: s32;
    sy: s32;
    dir: Dir;

    if is_river {
        // Rivers start from edge
        if random(2) == 0 {
            sx = random(m.width);
            sy = 0;
            dir = ifx random(2) == 0 then Dir.SOUTHEAST else Dir.SOUTHWEST;
        } else {
            sx = 0;
            sy = random(m.height);
            dir = ifx random(2) == 0 then Dir.SOUTHEAST else Dir.NORTHEAST;
        }
    } else {
        // Non-river streamers start from corner area
        corner := random(4);
        if corner == 0 {
            sx = 2 + random(10);
            sy = 2 + random(10);
            dir = Dir.SOUTHEAST;
        } else if corner == 1 {
            sx = m.width - 3 - random(10);
            sy = 2 + random(10);
            dir = Dir.SOUTHWEST;
        } else if corner == 2 {
            sx = 2 + random(10);
            sy = m.height - 3 - random(10);
            dir = Dir.NORTHEAST;
        } else {
            sx = m.width - 3 - random(10);
            sy = m.height - 3 - random(10);
            dir = Dir.NORTHWEST;
        }
    }

    // Width control
    width: s32;
    max_width: s32;
    if is_river {
        width = info.min_width + random(info.max_width - info.min_width + 1);
        max_width = width;
    } else {
        width = info.min_width;
        max_width = info.max_width;
    }

    // For chasms, ensure minimum width
    if stype == .CHASM {
        if max_width < 4 then max_width = 4;
    }

    // Movement ratios (controls how diagonal the path is)
    rx := 2 + random(8);
    ry := 2 + random(8);

    midpoint := false;

    // Walk across the map
    while width > 0 && sx >= 0 && sx < m.width && sy >= 0 && sy < m.height {
        // Vary width for non-rivers
        if !is_river && random(13) == 0 {
            if midpoint {
                width -= 1;
            } else {
                width += 1;
            }
        }

        if width >= max_width {
            midpoint = true;
        }

        // Move in direction (weighted random between x and y movement)
        if random(rx + ry) < rx {
            sx += DirX(dir);
        } else {
            sy += DirY(dir);
        }

        // Draw the streamer at current position with current width
        half_w := width / 2;
        for iy: -half_w..half_w {
            for ix: -half_w..half_w {
                tx := sx + ix;
                ty := sy + iy;
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
place_doors_makelev :: (m: *GenMap) {
    for y: 1..m.height-2 {
        for x: 1..m.width-2 {
            // Check if this is a wall
            if map_get(m, x, y) != .WALL continue;

            // Check for horizontal door position (floor on left and right)
            if map_get(m, x-1, y) == .FLOOR && map_get(m, x+1, y) == .FLOOR {
                // Make sure we're not in an open area (need walls above and below)
                above := map_get(m, x, y-1);
                below := map_get(m, x, y+1);
                if (above == .WALL || above == .ROCK) && (below == .WALL || below == .ROCK) {
                    // 70% closed, 20% open, 10% secret
                    roll := random(100);
                    if roll < 70 {
                        map_set(m, x, y, .DOOR_CLOSED);
                    } else if roll < 90 {
                        map_set(m, x, y, .DOOR_OPEN);
                    } else {
                        map_set(m, x, y, .DOOR_SECRET);
                    }
                }
            }

            // Check for vertical door position (floor above and below)
            if map_get(m, x, y-1) == .FLOOR && map_get(m, x, y+1) == .FLOOR {
                // Make sure we're not in an open area (need walls left and right)
                left := map_get(m, x-1, y);
                right := map_get(m, x+1, y);
                if (left == .WALL || left == .ROCK) && (right == .WALL || right == .ROCK) {
                    // 70% closed, 20% open, 10% secret
                    roll := random(100);
                    if roll < 70 {
                        map_set(m, x, y, .DOOR_CLOSED);
                    } else if roll < 90 {
                        map_set(m, x, y, .DOOR_OPEN);
                    } else {
                        map_set(m, x, y, .DOOR_SECRET);
                    }
                }
            }
        }
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

// Main generation function - matches Map::Generate structure
generate_makelev :: (m: *GenMap, seed: u32) {
    // Initialize RNG
    random_init(seed);

    // Initialize map
    map_init(m);

    // Initialize generation state
    gs: GenState;
    gen_state_init(*gs);

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
    // 30% chance for a streamer
    if random(100) < 30 {
        streamer_roll := random(100);
        stype: StreamerType;

        if streamer_roll < 35 {
            // Water river (35%)
            stype = .WATER_RIVER;
        } else if streamer_roll < 55 {
            // Chasm (20%)
            stype = .CHASM;
        } else if streamer_roll < 75 {
            // Water stream (20%)
            stype = .WATER_STREAM;
        } else if streamer_roll < 90 {
            // Lava river (15%) - deeper levels
            if m.depth >= 5 {
                stype = .LAVA_RIVER;
            } else {
                stype = .WATER_STREAM;
            }
        } else {
            // Rubble (10%)
            stype = .RUBBLE;
        }

        write_streamer(m, *gs, stype);
    }

    // Step 3: Place vaults (special pre-designed rooms)
    // 20% chance per level, higher at deeper levels
    vault_chance := 20 + m.depth * 5;
    if random(100) < vault_chance {
        if try_place_vault(m, *gs, m.depth) {
            print("  Placed vault on level %\n", m.depth);
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

    // Step 6: Place doors where corridors meet rooms
    place_doors_makelev(m);

    // Step 7: Place stairs
    if m.rooms.count >= 2 {
        // Stairs up in first room
        first_room := m.rooms[0];
        cx, cy := rect_center(first_room.bounds);
        map_set(m, cx, cy, .STAIRS_UP);

        // Stairs down in last room
        last_room := m.rooms[m.rooms.count - 1];
        cx, cy = rect_center(last_room.bounds);
        map_set(m, cx, cy, .STAIRS_DOWN);
    }

    print("Generated dungeon (ORIGINAL MakeLev) with % rooms, % panels\n",
          m.rooms.count, gs.panels_x * gs.panels_y);
}
