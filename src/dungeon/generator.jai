// Dungeon Generator using BSP (Binary Space Partitioning)
//
// Creates classic roguelike dungeons with rooms connected by corridors.
//
// Supports two modes:
//   EXTENDED - Enhanced generation with more room variety (default)
//   ORIGINAL - TODO: Exact MakeLev.cpp replication for identical dungeons
//
// Note: This file is loaded by main.jai which handles all imports and loads.

// Generation parameters
GEN_MIN_ROOM_SIZE :: 5;     // Minimum room dimension (interior)
GEN_MAX_ROOM_SIZE :: 12;    // Maximum room dimension (interior)
GEN_MIN_LEAF_SIZE :: 8;     // Minimum BSP leaf size
GEN_ROOM_MARGIN   :: 2;     // Margin between room and leaf edge

// BSP Node for space partitioning
BSPNode :: struct {
    bounds: Rect;
    left: *BSPNode;
    right: *BSPNode;
    room: Rect;         // Actual room carved in this leaf (if any)
    has_room: bool;
}

// Create a new BSP node
bsp_create :: (bounds: Rect) -> *BSPNode {
    node := New(BSPNode);
    node.bounds = bounds;
    node.left = null;
    node.right = null;
    node.has_room = false;
    return node;
}

// Free BSP tree
bsp_free :: (node: *BSPNode) {
    if node == null return;
    bsp_free(node.left);
    bsp_free(node.right);
    free(node);
}

// Split a BSP node into two children
bsp_split :: (node: *BSPNode, rng: *Random_State) -> bool {
    if node.left != null || node.right != null {
        return false;  // Already split
    }

    w := rect_width(node.bounds);
    h := rect_height(node.bounds);

    // Determine split direction
    // Prefer to split the longer dimension
    split_horizontal: bool;
    if w > h && cast(float32)w / cast(float32)h >= 1.25 {
        split_horizontal = false;  // Split vertically (divide width)
    } else if h > w && cast(float32)h / cast(float32)w >= 1.25 {
        split_horizontal = true;   // Split horizontally (divide height)
    } else {
        split_horizontal = random_get(rng) % 2 == 0;
    }

    // Determine max split position
    max_split: s32;
    if split_horizontal {
        max_split = h - GEN_MIN_LEAF_SIZE;
    } else {
        max_split = w - GEN_MIN_LEAF_SIZE;
    }

    if max_split <= GEN_MIN_LEAF_SIZE {
        return false;  // Too small to split
    }

    // Choose split position
    split_pos := GEN_MIN_LEAF_SIZE + cast(s32)(random_get(rng) % cast(u64)(max_split - GEN_MIN_LEAF_SIZE));

    // Create children
    if split_horizontal {
        node.left = bsp_create(.{
            node.bounds.x1, node.bounds.y1,
            node.bounds.x2, node.bounds.y1 + split_pos - 1
        });
        node.right = bsp_create(.{
            node.bounds.x1, node.bounds.y1 + split_pos,
            node.bounds.x2, node.bounds.y2
        });
    } else {
        node.left = bsp_create(.{
            node.bounds.x1, node.bounds.y1,
            node.bounds.x1 + split_pos - 1, node.bounds.y2
        });
        node.right = bsp_create(.{
            node.bounds.x1 + split_pos, node.bounds.y1,
            node.bounds.x2, node.bounds.y2
        });
    }

    return true;
}

// Recursively split BSP tree to target depth
bsp_split_recursive :: (node: *BSPNode, rng: *Random_State, depth: s32) {
    if depth <= 0 return;

    if bsp_split(node, rng) {
        bsp_split_recursive(node.left, rng, depth - 1);
        bsp_split_recursive(node.right, rng, depth - 1);
    }
}

// Create a room in a BSP leaf
bsp_create_room :: (node: *BSPNode, m: *GenMap, rng: *Random_State) {
    if node.left != null && node.right != null {
        // Not a leaf, recurse
        bsp_create_room(node.left, m, rng);
        bsp_create_room(node.right, m, rng);
        return;
    }

    // This is a leaf - create a room
    // Room must fit within bounds with margin
    min_x := node.bounds.x1 + GEN_ROOM_MARGIN;
    max_x := node.bounds.x2 - GEN_ROOM_MARGIN;
    min_y := node.bounds.y1 + GEN_ROOM_MARGIN;
    max_y := node.bounds.y2 - GEN_ROOM_MARGIN;

    available_w := max_x - min_x;
    available_h := max_y - min_y;

    if available_w < GEN_MIN_ROOM_SIZE || available_h < GEN_MIN_ROOM_SIZE {
        return;  // Not enough space for a room
    }

    // Random room size
    room_w := GEN_MIN_ROOM_SIZE + cast(s32)(random_get(rng) % cast(u64)(min(available_w, GEN_MAX_ROOM_SIZE) - GEN_MIN_ROOM_SIZE + 1));
    room_h := GEN_MIN_ROOM_SIZE + cast(s32)(random_get(rng) % cast(u64)(min(available_h, GEN_MAX_ROOM_SIZE) - GEN_MIN_ROOM_SIZE + 1));

    // Random room position within available space
    room_x := min_x;
    room_y := min_y;
    if available_w > room_w {
        room_x = min_x + cast(s32)(random_get(rng) % cast(u64)(available_w - room_w + 1));
    }
    if available_h > room_h {
        room_y = min_y + cast(s32)(random_get(rng) % cast(u64)(available_h - room_h + 1));
    }

    node.room = .{room_x, room_y, room_x + room_w - 1, room_y + room_h - 1};
    node.has_room = true;

    // Choose a random room shape
    // Weighted: rectangles more common, special shapes less common
    shape_roll := random_get(rng) % 100;
    shape: RoomShape;
    if shape_roll < 50 {
        shape = .RECTANGLE;
    } else if shape_roll < 70 {
        shape = .CIRCLE;
    } else if shape_roll < 80 {
        shape = .OCTAGON;
    } else if shape_roll < 90 {
        shape = .CROSS;
    } else {
        shape = .DIAMOND;
    }

    // Cross and diamond need larger rooms to look good
    if (shape == .CROSS || shape == .DIAMOND) && (room_w < 7 || room_h < 7) {
        shape = .RECTANGLE;
    }

    // Carve the room into the map
    map_carve_room(m, node.room, shape);
}

// Get a room from a BSP subtree (for corridor connection)
bsp_get_room :: (node: *BSPNode, rng: *Random_State) -> Rect, bool {
    if node == null {
        return .{}, false;
    }

    if node.has_room {
        return node.room, true;
    }

    // Get room from children
    left_room, left_ok := bsp_get_room(node.left, rng);
    right_room, right_ok := bsp_get_room(node.right, rng);

    if left_ok && right_ok {
        // Return one randomly
        if random_get(rng) % 2 == 0 {
            return left_room, true;
        } else {
            return right_room, true;
        }
    } else if left_ok {
        return left_room, true;
    } else if right_ok {
        return right_room, true;
    }

    return .{}, false;
}

// Connect rooms in BSP tree with corridors
bsp_connect_rooms :: (node: *BSPNode, m: *GenMap, rng: *Random_State) {
    if node == null return;
    if node.left == null || node.right == null return;

    // Recursively connect children first
    bsp_connect_rooms(node.left, m, rng);
    bsp_connect_rooms(node.right, m, rng);

    // Connect a room from left subtree to a room from right subtree
    left_room, left_ok := bsp_get_room(node.left, rng);
    right_room, right_ok := bsp_get_room(node.right, rng);

    if left_ok && right_ok {
        // Get center points
        lx, ly := rect_center(left_room);
        rx, ry := rect_center(right_room);

        // Carve corridor between them
        map_carve_corridor(m, lx, ly, rx, ry);
    }
}

// Main dungeon generation function
generate_dungeon :: (m: *GenMap, seed: u64 = 0, mode: GeneratorMode = .EXTENDED, depth: s32 = 1) {
    if mode == .ORIGINAL {
        generate_dungeon_original(m, cast(u32)seed, depth);
        return;
    }

    // EXTENDED mode - uses Jai's Random module
    rng: Random_State;
    if seed == 0 {
        seed = cast(u64) current_time_monotonic().low;
    }
    random_seed(*rng, seed);

    // Initialize map
    map_init(m);
    m.depth = depth;

    // Create BSP tree covering the map (with border margin)
    root := bsp_create(.{1, 1, m.width - 2, m.height - 2});

    // Split the tree (4-5 levels gives good room distribution)
    bsp_split_recursive(root, *rng, 4);

    // Create rooms in leaves
    bsp_create_room(root, m, *rng);

    // Connect rooms with corridors
    bsp_connect_rooms(root, m, *rng);

    // Roughen corridors for more natural look
    map_roughen_corridors(m, *rng);

    // Place doors where corridors meet rooms
    map_place_doors(m);

    // Place water pools in some rooms (20% chance per room)
    for room: m.rooms {
        if random_get(*rng) % 5 == 0 {
            cx, cy := rect_center(room.bounds);
            // Offset from center slightly
            cx += cast(s32)(random_get(*rng) % 3) - 1;
            cy += cast(s32)(random_get(*rng) % 3) - 1;
            radius := 1 + cast(s32)(random_get(*rng) % 2);
            map_place_pool(m, cx, cy, radius);
        }
    }

    // Place stairs
    if m.rooms.count >= 2 {
        // Stairs up in first room
        first_room := m.rooms[0];
        cx, cy := rect_center(first_room.bounds);
        // Make sure we don't place on water
        if map_get(m, cx, cy) == .WATER {
            cx += 1;
        }
        map_set(m, cx, cy, .STAIRS_UP);

        // Stairs down in last room
        last_room := m.rooms[m.rooms.count - 1];
        cx, cy = rect_center(last_room.bounds);
        if map_get(m, cx, cy) == .WATER {
            cx += 1;
        }
        map_set(m, cx, cy, .STAIRS_DOWN);
    }

    // Clean up BSP tree
    bsp_free(root);

    print("Generated dungeon (EXTENDED) with % rooms\n", m.rooms.count);
}

// Original-compatible dungeon generation using MT19937
// Uses MakeLev panel-based generation
generate_dungeon_original :: (m: *GenMap, seed: u32, depth: s32 = 1) {
    // Use the MakeLev-style generation
    generate_makelev(m, seed, depth = depth);
}
