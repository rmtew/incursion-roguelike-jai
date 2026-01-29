// Map data structures for dungeon generation
//
// A simple tile-based map with terrain types.
//
// Note: This file is loaded by main.jai which handles all imports.

// Map dimensions (matching Incursion's defaults)
MAP_WIDTH  :: 80;
MAP_HEIGHT :: 50;

// Terrain types
Terrain :: enum u8 {
    ROCK;           // Solid rock (default fill)
    WALL;           // Constructed wall
    FLOOR;          // Room floor
    CORRIDOR;       // Corridor floor
    DOOR_CLOSED;    // Closed door
    DOOR_OPEN;      // Open door
    DOOR_SECRET;    // Secret door (looks like wall)
    STAIRS_UP;      // Stairs going up
    STAIRS_DOWN;    // Stairs going down
    WATER;          // Water
    CHASM;          // Bottomless pit
    LAVA;           // Molten lava
    TRAP;           // Visible trap ('^')
    TRAP_HIDDEN;    // Hidden trap (looks like floor until triggered)
    PILLAR;         // Pillar/column (blocks movement, not sight fully)
    RUBBLE;         // Rubble/debris (passable but difficult)
}

// Get the glyph character for a terrain type
// Returns u16 to allow extended glyph codes (GLYPH_* values 256+)
terrain_glyph :: (t: Terrain) -> u16 {
    if t == {
        case .ROCK;         return #char " ";
        case .WALL;         return #char "#";
        case .FLOOR;        return #char ".";
        case .CORRIDOR;     return #char ".";
        case .DOOR_CLOSED;  return #char "+";
        case .DOOR_OPEN;    return #char "'";
        case .DOOR_SECRET;  return #char "#";
        case .STAIRS_UP;    return #char "<";
        case .STAIRS_DOWN;  return #char ">";
        case .WATER;        return #char "~";
        case .CHASM;        return #char " ";
        case .LAVA;         return #char "~";
        case .TRAP;         return #char "^";
        case .TRAP_HIDDEN;  return #char ".";  // Looks like floor until found
        case .PILLAR;       return #char "0";  // Pillar/column
        case .RUBBLE;       return #char ";";  // Rubble/debris
    }
    return #char "?";
}

// Is this terrain passable?
terrain_passable :: (t: Terrain) -> bool {
    return t == .FLOOR || t == .CORRIDOR || t == .DOOR_OPEN ||
           t == .STAIRS_UP || t == .STAIRS_DOWN || t == .RUBBLE;
}

// Is this terrain solid (blocks movement and sight)?
terrain_solid :: (t: Terrain) -> bool {
    return t == .ROCK || t == .WALL || t == .DOOR_CLOSED || t == .DOOR_SECRET || t == .PILLAR;
}

// Rectangle helper
Rect :: struct {
    x1, y1: s32;  // Top-left corner
    x2, y2: s32;  // Bottom-right corner (inclusive)
}

rect_width :: (r: Rect) -> s32 {
    return r.x2 - r.x1 + 1;
}

rect_height :: (r: Rect) -> s32 {
    return r.y2 - r.y1 + 1;
}

rect_center :: (r: Rect) -> s32, s32 {
    return (r.x1 + r.x2) / 2, (r.y1 + r.y2) / 2;
}

rect_contains :: (r: Rect, x: s32, y: s32) -> bool {
    return x >= r.x1 && x <= r.x2 && y >= r.y1 && y <= r.y2;
}

// Room structure (for tracking placed rooms)
Room :: struct {
    bounds: Rect;       // Room boundaries (walls are outside this)
    connected: bool;    // Has this room been connected to the dungeon?
}

// Entity position for monsters/items
EntityPos :: struct {
    x: s32;
    y: s32;
    cr: s32;            // Challenge rating (monsters) or value tier (items)
    type_id: s32;       // Monster/item type identifier (for future use)
    party_id: s32;      // Creatures in same party don't fight each other
    room_index: s32;    // Which room this entity belongs to (-1 = corridor)

    // Monster flags
    is_aquatic: bool;   // Must be placed in water
    is_aerial: bool;    // Can be placed in fall terrain
    is_sleeping: bool;  // Monster is asleep

    // Item flags
    is_cursed: bool;    // Item is cursed
    is_good: bool;      // Item is high quality (IG_GOOD)
    is_staple: bool;    // Item is essential consumable (IG_STAPLE)
    is_chest: bool;     // Item is a chest/container

    // Rendering (set at spawn time from resource database)
    glyph: u16;         // Character code or GLYPH_* constant (256+)
    fg_color: u8;       // ANSI color index (0-15)
}

// Door flags (from Defines.h:920-930)
// Per spec: 10% open, ~45% locked, ~45% unlocked, ~14% secret
DF_VERTICAL :: 0x01;  // Vertical orientation (walls above/below)
DF_OPEN     :: 0x02;  // Door is currently open
DF_STUCK    :: 0x04;  // Door is stuck/jammed
DF_LOCKED   :: 0x08;  // Door is locked
DF_TRAPPED  :: 0x10;  // Door is trapped
DF_SECRET   :: 0x20;  // Door is secret (hidden)
DF_BROKEN   :: 0x40;  // Door has been broken down
DF_SEARCHED :: 0x80;  // Door has been searched for traps

// Door information for tracking state
DoorInfo :: struct {
    x: s32;
    y: s32;
    flags: u8;          // DF_* flags
    lock_dc: s32;       // Lock difficulty (if DF_LOCKED)
    trap_type: s32;     // Trap type (if DF_TRAPPED)
}

// Tile display info (for visual variety via regions)
TileDisplay :: struct {
    glyph: u16;         // Character code or GLYPH_* constant (256+)
    fg_color: s64;      // Foreground color constant
    use_custom: bool;   // If true, use glyph/fg_color instead of terrain default
}

// Map structure
GenMap :: struct {
    width: s32;
    height: s32;
    tiles: [MAP_WIDTH * MAP_HEIGHT] Terrain;
    tile_display: [MAP_WIDTH * MAP_HEIGHT] TileDisplay;  // Visual info per tile
    rooms: [..] Room;
    depth: s32;         // Dungeon depth level

    // Population (filled by populate_dungeon)
    monsters: [..] EntityPos;
    items: [..] EntityPos;

    // Doors with state tracking
    doors: [..] DoorInfo;
}

// Initialize a new map filled with rock
map_init :: (m: *GenMap, width: s32 = MAP_WIDTH, height: s32 = MAP_HEIGHT) {
    m.width = width;
    m.height = height;
    m.depth = 1;

    // Fill with rock
    for *tile: m.tiles {
        tile.* = .ROCK;
    }

    // Clear tile display info
    for *td: m.tile_display {
        td.glyph = 0;
        td.fg_color = 0;
        td.use_custom = false;
    }

    // Clear arrays
    array_reset(*m.rooms);
    array_reset(*m.monsters);
    array_reset(*m.items);
    array_reset(*m.doors);
}

// Free map resources
map_free :: (m: *GenMap) {
    array_free(m.rooms);
    array_free(m.monsters);
    array_free(m.items);
    array_free(m.doors);
}

// Get terrain at position (returns ROCK if out of bounds)
map_get :: (m: *GenMap, x: s32, y: s32) -> Terrain {
    if x < 0 || x >= m.width || y < 0 || y >= m.height {
        return .ROCK;
    }
    return m.tiles[y * m.width + x];
}

// Set terrain at position
// Clears any custom TileDisplay so the terrain's default rendering is used
map_set :: (m: *GenMap, x: s32, y: s32, terrain: Terrain) {
    if x < 0 || x >= m.width || y < 0 || y >= m.height {
        return;
    }
    idx := y * m.width + x;
    m.tiles[idx] = terrain;
    m.tile_display[idx].use_custom = false;  // Clear stale display info
}

// Set terrain with custom display info (for region terrain variety)
map_set_with_display :: (m: *GenMap, x: s32, y: s32, terrain: Terrain, glyph: u16, fg_color: s64) {
    if x < 0 || x >= m.width || y < 0 || y >= m.height {
        return;
    }
    idx := y * m.width + x;
    m.tiles[idx] = terrain;
    m.tile_display[idx].glyph = glyph;
    m.tile_display[idx].fg_color = fg_color;
    m.tile_display[idx].use_custom = true;
}

// Get tile display info at position
map_get_display :: (m: *GenMap, x: s32, y: s32) -> *TileDisplay {
    if x < 0 || x >= m.width || y < 0 || y >= m.height {
        return null;
    }
    return *m.tile_display[y * m.width + x];
}

// Check if position is in bounds
map_in_bounds :: (m: *GenMap, x: s32, y: s32) -> bool {
    return x >= 0 && x < m.width && y >= 0 && y < m.height;
}

// Fill a rectangular area with a terrain type
map_fill_rect :: (m: *GenMap, r: Rect, terrain: Terrain) {
    for y: r.y1..r.y2 {
        for x: r.x1..r.x2 {
            map_set(m, x, y, terrain);
        }
    }
}

// Draw walls around a rectangular area
map_draw_walls :: (m: *GenMap, r: Rect) {
    // Top and bottom walls
    for x: r.x1..r.x2 {
        map_set(m, x, r.y1, .WALL);
        map_set(m, x, r.y2, .WALL);
    }
    // Left and right walls
    for y: r.y1..r.y2 {
        map_set(m, r.x1, y, .WALL);
        map_set(m, r.x2, y, .WALL);
    }
}

// Room shapes
RoomShape :: enum {
    RECTANGLE;
    CIRCLE;
    CROSS;
    DIAMOND;
    OCTAGON;
    CAVERN;     // Irregular natural cave
    CASTLE;     // Subdivided with internal walls
}

// Carve a rectangular room (floor inside, walls around)
map_carve_room :: (m: *GenMap, r: Rect, shape: RoomShape = .RECTANGLE, rng: *Random_State = null) {
    if shape == {
        case .RECTANGLE;
            map_carve_room_rectangle(m, r);
        case .CIRCLE;
            map_carve_room_circle(m, r);
        case .CROSS;
            map_carve_room_cross(m, r);
        case .DIAMOND;
            map_carve_room_diamond(m, r);
        case .OCTAGON;
            map_carve_room_octagon(m, r);
        case .CAVERN;
            map_carve_room_cavern(m, r, rng);
        case .CASTLE;
            map_carve_room_castle(m, r, rng);
    }

    // Track this room
    room: Room;
    room.bounds = r;
    room.connected = false;
    array_add(*m.rooms, room);
}

map_carve_room_rectangle :: (m: *GenMap, r: Rect) {
    // Draw walls around the room
    wall_rect := Rect.{r.x1 - 1, r.y1 - 1, r.x2 + 1, r.y2 + 1};
    map_draw_walls(m, wall_rect);

    // Fill interior with floor
    map_fill_rect(m, r, .FLOOR);
}

map_carve_room_circle :: (m: *GenMap, r: Rect) {
    cx, cy := rect_center(r);
    radius_x := rect_width(r) / 2;
    radius_y := rect_height(r) / 2;
    radius := min(radius_x, radius_y);

    // Draw circular room
    for y: r.y1-1..r.y2+1 {
        for x: r.x1-1..r.x2+1 {
            dx := x - cx;
            dy := y - cy;
            dist_sq := dx*dx + dy*dy;
            radius_sq := radius * radius;

            if dist_sq <= radius_sq {
                map_set(m, x, y, .FLOOR);
            } else if dist_sq <= (radius+1) * (radius+1) {
                // Only place wall if currently rock
                if map_get(m, x, y) == .ROCK {
                    map_set(m, x, y, .WALL);
                }
            }
        }
    }
}

map_carve_room_cross :: (m: *GenMap, r: Rect) {
    cx, cy := rect_center(r);
    w := rect_width(r);
    h := rect_height(r);
    arm_w := max(w / 3, 2);
    arm_h := max(h / 3, 2);

    // Horizontal arm
    h_rect := Rect.{r.x1, cy - arm_h/2, r.x2, cy + arm_h/2};
    map_carve_room_rectangle(m, h_rect);

    // Vertical arm (overlaps center)
    v_rect := Rect.{cx - arm_w/2, r.y1, cx + arm_w/2, r.y2};
    // Just fill floor, walls already drawn by horizontal
    map_fill_rect(m, v_rect, .FLOOR);

    // Add walls around vertical arm where needed
    for y: v_rect.y1-1..v_rect.y2+1 {
        if map_get(m, v_rect.x1-1, y) == .ROCK {
            map_set(m, v_rect.x1-1, y, .WALL);
        }
        if map_get(m, v_rect.x2+1, y) == .ROCK {
            map_set(m, v_rect.x2+1, y, .WALL);
        }
    }
    for x: v_rect.x1..v_rect.x2 {
        if map_get(m, x, v_rect.y1-1) == .ROCK {
            map_set(m, x, v_rect.y1-1, .WALL);
        }
        if map_get(m, x, v_rect.y2+1) == .ROCK {
            map_set(m, x, v_rect.y2+1, .WALL);
        }
    }
}

map_carve_room_diamond :: (m: *GenMap, r: Rect) {
    cx, cy := rect_center(r);
    radius_x := rect_width(r) / 2;
    radius_y := rect_height(r) / 2;

    // Diamond uses manhattan distance
    for y: r.y1-1..r.y2+1 {
        for x: r.x1-1..r.x2+1 {
            dx := abs(x - cx);
            dy := abs(y - cy);

            // Scale to make it fit the rect
            dist := cast(float32)dx / cast(float32)radius_x + cast(float32)dy / cast(float32)radius_y;

            if dist <= 1.0 {
                map_set(m, x, y, .FLOOR);
            } else if dist <= 1.2 {
                if map_get(m, x, y) == .ROCK {
                    map_set(m, x, y, .WALL);
                }
            }
        }
    }
}

map_carve_room_octagon :: (m: *GenMap, r: Rect) {
    // Octagon: rectangle with corners cut off
    map_carve_room_rectangle(m, r);

    // Cut corners (replace with wall)
    corner_size := min(rect_width(r), rect_height(r)) / 4;
    if corner_size < 1 corner_size = 1;

    // Top-left corner
    for i: 0..corner_size-1 {
        for j: 0..corner_size-1-i {
            map_set(m, r.x1 + j, r.y1 + i, .WALL);
        }
    }
    // Top-right corner
    for i: 0..corner_size-1 {
        for j: 0..corner_size-1-i {
            map_set(m, r.x2 - j, r.y1 + i, .WALL);
        }
    }
    // Bottom-left corner
    for i: 0..corner_size-1 {
        for j: 0..corner_size-1-i {
            map_set(m, r.x1 + j, r.y2 - i, .WALL);
        }
    }
    // Bottom-right corner
    for i: 0..corner_size-1 {
        for j: 0..corner_size-1-i {
            map_set(m, r.x2 - j, r.y2 - i, .WALL);
        }
    }
}

map_carve_room_cavern :: (m: *GenMap, r: Rect, rng: *Random_State) {
    // Cellular automata-style irregular cavern
    // Start with random fill, then smooth

    w := rect_width(r);
    h := rect_height(r);

    // Temporary grid for cellular automata
    grid: [400] bool;  // Max 20x20 room
    if w * h > 400 {
        // Fall back to rectangle for huge rooms
        map_carve_room_rectangle(m, r);
        return;
    }

    // Initial random fill (45% floor)
    for i: 0..w*h-1 {
        if rng != null {
            grid[i] = random_get(rng) % 100 < 45;
        } else {
            grid[i] = i % 2 == 0;
        }
    }

    // Ensure edges are walls
    for x: 0..w-1 {
        grid[x] = false;
        grid[(h-1) * w + x] = false;
    }
    for y: 0..h-1 {
        grid[y * w] = false;
        grid[y * w + w - 1] = false;
    }

    // Cellular automata smoothing (4 iterations)
    for iter: 0..3 {
        new_grid: [400] bool;
        for y: 1..h-2 {
            for x: 1..w-2 {
                // Count floor neighbors
                floors := 0;
                for dy: -1..1 {
                    for dx: -1..1 {
                        if grid[(y + dy) * w + (x + dx)] floors += 1;
                    }
                }
                // Rule: become floor if 5+ neighbors are floor
                new_grid[y * w + x] = floors >= 5;
            }
        }
        for i: 0..w*h-1 {
            grid[i] = new_grid[i];
        }
    }

    // Ensure center is floor (for connectivity)
    cx := w / 2;
    cy := h / 2;
    grid[cy * w + cx] = true;
    grid[cy * w + cx + 1] = true;
    grid[cy * w + cx - 1] = true;
    grid[(cy + 1) * w + cx] = true;
    grid[(cy - 1) * w + cx] = true;

    // Apply to map
    for y: 0..h-1 {
        for x: 0..w-1 {
            mx := r.x1 + x;
            my := r.y1 + y;
            if grid[y * w + x] {
                map_set(m, mx, my, .FLOOR);
            } else {
                // Place wall only if adjacent to floor
                has_floor_neighbor := false;
                for dy: -1..1 {
                    for dx: -1..1 {
                        nx := x + dx;
                        ny := y + dy;
                        if nx >= 0 && nx < w && ny >= 0 && ny < h {
                            if grid[ny * w + nx] has_floor_neighbor = true;
                        }
                    }
                }
                if has_floor_neighbor {
                    map_set(m, mx, my, .WALL);
                }
            }
        }
    }
}

map_carve_room_castle :: (m: *GenMap, r: Rect, rng: *Random_State) {
    // Castle: rectangular room subdivided by internal walls with doors
    map_carve_room_rectangle(m, r);

    w := rect_width(r);
    h := rect_height(r);

    // Need at least 7x7 for subdivision
    if w < 7 || h < 7 return;

    // Decide split direction based on shape
    split_vertical := w > h;
    if rng != null && w == h {
        split_vertical = random_get(rng) % 2 == 0;
    }

    if split_vertical {
        // Vertical wall
        wx := r.x1 + w / 2;
        for y: r.y1..r.y2 {
            map_set(m, wx, y, .WALL);
        }
        // Door in the wall
        door_y := r.y1 + 1;
        if rng != null {
            door_y = r.y1 + 1 + cast(s32)(random_get(rng) % cast(u64)(h - 2));
        }
        map_set(m, wx, door_y, .DOOR_CLOSED);
    } else {
        // Horizontal wall
        wy := r.y1 + h / 2;
        for x: r.x1..r.x2 {
            map_set(m, x, wy, .WALL);
        }
        // Door in the wall
        door_x := r.x1 + 1;
        if rng != null {
            door_x = r.x1 + 1 + cast(s32)(random_get(rng) % cast(u64)(w - 2));
        }
        map_set(m, door_x, wy, .DOOR_CLOSED);
    }
}

// Carve a corridor between two points
map_carve_corridor :: (m: *GenMap, x1: s32, y1: s32, x2: s32, y2: s32) {
    x := x1;
    y := y1;

    // Simple L-shaped corridor
    // First go horizontal, then vertical (or vice versa randomly)
    horizontal_first := (x1 + y1) % 2 == 0;  // Deterministic based on position

    if horizontal_first {
        // Horizontal segment
        dx: s32 = cast(s32) ifx x2 > x1 then 1 else -1;
        while x != x2 {
            if map_get(m, x, y) == .ROCK {
                map_set(m, x, y, .CORRIDOR);
            }
            x += dx;
        }
        // Vertical segment
        dy: s32 = cast(s32) ifx y2 > y1 then 1 else -1;
        while y != y2 {
            if map_get(m, x, y) == .ROCK {
                map_set(m, x, y, .CORRIDOR);
            }
            y += dy;
        }
    } else {
        // Vertical segment first
        dy: s32 = cast(s32) ifx y2 > y1 then 1 else -1;
        while y != y2 {
            if map_get(m, x, y) == .ROCK {
                map_set(m, x, y, .CORRIDOR);
            }
            y += dy;
        }
        // Horizontal segment
        dx: s32 = cast(s32) ifx x2 > x1 then 1 else -1;
        while x != x2 {
            if map_get(m, x, y) == .ROCK {
                map_set(m, x, y, .CORRIDOR);
            }
            x += dx;
        }
    }

    // Place final tile
    if map_get(m, x, y) == .ROCK {
        map_set(m, x, y, .CORRIDOR);
    }
}

// Place a door where corridor meets room
map_place_doors :: (m: *GenMap) {
    for y: 1..m.height-2 {
        for x: 1..m.width-2 {
            t := map_get(m, x, y);
            if t != .CORRIDOR continue;

            // Check if this corridor tile is adjacent to a room floor
            // and has walls on opposite sides (doorway pattern)

            // Horizontal doorway: walls above and below, floor on sides
            n := map_get(m, x, y-1);
            s := map_get(m, x, y+1);
            e := map_get(m, x+1, y);
            w := map_get(m, x-1, y);

            is_horizontal_door := (terrain_solid(n) && terrain_solid(s) &&
                                   (e == .FLOOR || w == .FLOOR));
            is_vertical_door := (terrain_solid(e) && terrain_solid(w) &&
                                 (n == .FLOOR || s == .FLOOR));

            if is_horizontal_door || is_vertical_door {
                map_set(m, x, y, .DOOR_CLOSED);
            }
        }
    }
}

// Place a water pool in a room
map_place_pool :: (m: *GenMap, cx: s32, cy: s32, radius: s32) {
    for dy: -radius..radius {
        for dx: -radius..radius {
            dist_sq := dx*dx + dy*dy;
            if dist_sq <= radius*radius {
                x := cx + dx;
                y := cy + dy;
                // Only place water on floor tiles
                if map_get(m, x, y) == .FLOOR {
                    map_set(m, x, y, .WATER);
                }
            }
        }
    }
}

// Add some irregular edges to corridors (make them look more natural)
map_roughen_corridors :: (m: *GenMap, rng: *Random_State) {
    // Find corridor tiles and occasionally widen them
    for y: 2..m.height-3 {
        for x: 2..m.width-3 {
            if map_get(m, x, y) != .CORRIDOR continue;

            // 20% chance to expand into adjacent rock
            if random_get(rng) % 5 == 0 {
                dir := random_get(rng) % 4;
                nx := x;
                ny := y;
                if dir == 0 { nx = x - 1; }
                else if dir == 1 { nx = x + 1; }
                else if dir == 2 { ny = y - 1; }
                else { ny = y + 1; }

                if map_get(m, nx, ny) == .ROCK {
                    map_set(m, nx, ny, .CORRIDOR);
                }
            }
        }
    }
}

// Helper: abs for s32
abs :: inline (x: s32) -> s32 {
    return ifx x < 0 then -x else x;
}
