// Game Loop - Core game logic
//
// init_game: Generate dungeon, place player, calculate lighting/FOV
// do_action: Validate and execute an action, return result
// free_game: Release resources
//
// Movement: Walking into a closed door auto-opens it (one action, matching
// Incursion behavior). Locked doors block with a message.

// ============================================================================
// Initialization / Shutdown
// ============================================================================

// Initialize a new game with given seed and depth.
// Generates dungeon, places player at first room center, calculates lighting/FOV.
init_game :: (gs: *GameState, seed: u64, depth: s32 = 1) {
    gs.seed = seed;
    gs.depth = depth;
    gs.turn = 0;
    gs.player_x = 0;
    gs.player_y = 0;

    // Seed game-phase RNG (separate from dungeon generation RNG)
    mt_seed(*gs.rng, cast(u32)(seed ^ 0xDEADBEEF));

    // Generate dungeon (uses global_mt internally)
    generate_dungeon(*gs.dungeon, seed, depth = depth);

    // Place player at first room center
    game_init_player_position(gs);

    // Calculate initial lighting and FOV
    calculate_lighting(*gs.dungeon);
    calculate_fov(*gs.dungeon, gs.player_x, gs.player_y);

    gs.initialized = true;
}

// Free game resources
free_game :: (gs: *GameState) {
    map_free(*gs.dungeon);
    gs.initialized = false;
}

// ============================================================================
// Action Dispatch
// ============================================================================

// Execute an action. Returns an ActionResult describing what happened.
// The optional dir parameter is used for OPEN_DOOR/CLOSE_DOOR to specify
// which adjacent door to operate on.
do_action :: (gs: *GameState, action: Action, dir: Dir = .CENTER) -> ActionResult {
    result: ActionResult;

    if !gs.initialized {
        result.message = "Game not initialized.";
        return result;
    }

    if action == {
        case .NONE;
            result.message = "No action.";
            return result;

        case .MOVE_N;  #through;
        case .MOVE_S;  #through;
        case .MOVE_E;  #through;
        case .MOVE_W;  #through;
        case .MOVE_NE; #through;
        case .MOVE_NW; #through;
        case .MOVE_SE; #through;
        case .MOVE_SW;
            return do_move(gs, action);

        case .WAIT;
            advance_turn(gs);
            result.success = true;
            result.turn_advanced = true;
            result.message = "You wait.";
            return result;

        case .OPEN_DOOR;
            return do_open_door(gs, dir);

        case .CLOSE_DOOR;
            return do_close_door(gs, dir);
    }

    result.message = "Unknown action.";
    return result;
}

// ============================================================================
// Movement
// ============================================================================

// Execute a movement action.
// Walking into a closed door auto-opens it (one action, matching Incursion).
do_move :: (gs: *GameState, action: Action) -> ActionResult {
    result: ActionResult;

    dx, dy := action_to_delta(action);
    new_x := gs.player_x + dx;
    new_y := gs.player_y + dy;

    if !map_in_bounds(*gs.dungeon, new_x, new_y) {
        result.blocked_reason = "The edge of the world blocks you.";
        return result;
    }

    terrain := map_get(*gs.dungeon, new_x, new_y);

    // Closed door: auto-open and move in one action
    if terrain == .DOOR_CLOSED {
        // Check if locked
        door_info := find_door_info(*gs.dungeon, new_x, new_y);
        if door_info != null && (door_info.flags & DF_LOCKED) != 0 {
            result.blocked_reason = "The door is locked.";
            return result;
        }

        // Open the door
        map_set(*gs.dungeon, new_x, new_y, .DOOR_OPEN);
        if door_info != null {
            door_info.flags |= DF_OPEN;
        }

        // Move into the doorway
        gs.player_x = new_x;
        gs.player_y = new_y;
        advance_turn(gs);
        result.success = true;
        result.turn_advanced = true;
        result.door_opened = true;
        result.message = "You open the door.";
        return result;
    }

    // Secret door: blocks like a wall
    if terrain == .DOOR_SECRET {
        result.blocked_reason = "Something blocks you.";
        return result;
    }

    // Normal passability check
    if !game_can_move_to(*gs.dungeon, new_x, new_y) {
        result.blocked_reason = "You can't move there.";
        return result;
    }

    // Move
    gs.player_x = new_x;
    gs.player_y = new_y;
    advance_turn(gs);
    result.success = true;
    result.turn_advanced = true;
    result.message = "You move.";
    return result;
}

// Check if a tile is passable for normal movement.
// Closed doors are handled separately in do_move (auto-open).
game_can_move_to :: (m: *GenMap, x: s32, y: s32) -> bool {
    if !map_in_bounds(m, x, y) return false;

    t := map_get(m, x, y);
    return t == .FLOOR || t == .CORRIDOR || t == .DOOR_OPEN ||
           t == .STAIRS_UP || t == .STAIRS_DOWN ||
           terrain_is_water(t) || t == .RUBBLE;
}

// ============================================================================
// Door Operations
// ============================================================================

// Explicitly open a door in the given direction
do_open_door :: (gs: *GameState, dir: Dir) -> ActionResult {
    result: ActionResult;

    dx := cast(s32) DirX(dir);
    dy := cast(s32) DirY(dir);
    target_x := gs.player_x + dx;
    target_y := gs.player_y + dy;

    if !map_in_bounds(*gs.dungeon, target_x, target_y) {
        result.blocked_reason = "Nothing to open there.";
        return result;
    }

    terrain := map_get(*gs.dungeon, target_x, target_y);
    if terrain != .DOOR_CLOSED {
        result.blocked_reason = "There is no closed door there.";
        return result;
    }

    // Check if locked
    door_info := find_door_info(*gs.dungeon, target_x, target_y);
    if door_info != null && (door_info.flags & DF_LOCKED) != 0 {
        result.blocked_reason = "The door is locked.";
        return result;
    }

    // Open it
    map_set(*gs.dungeon, target_x, target_y, .DOOR_OPEN);
    if door_info != null {
        door_info.flags |= DF_OPEN;
    }

    advance_turn(gs);
    result.success = true;
    result.turn_advanced = true;
    result.door_opened = true;
    result.message = "You open the door.";
    return result;
}

// Close a door in the given direction
do_close_door :: (gs: *GameState, dir: Dir) -> ActionResult {
    result: ActionResult;

    dx := cast(s32) DirX(dir);
    dy := cast(s32) DirY(dir);
    target_x := gs.player_x + dx;
    target_y := gs.player_y + dy;

    if !map_in_bounds(*gs.dungeon, target_x, target_y) {
        result.blocked_reason = "Nothing to close there.";
        return result;
    }

    terrain := map_get(*gs.dungeon, target_x, target_y);
    if terrain != .DOOR_OPEN {
        result.blocked_reason = "There is no open door there.";
        return result;
    }

    // Close it
    map_set(*gs.dungeon, target_x, target_y, .DOOR_CLOSED);
    door_info := find_door_info(*gs.dungeon, target_x, target_y);
    if door_info != null {
        door_info.flags &= xx,no_check ~DF_OPEN;
    }

    advance_turn(gs);
    result.success = true;
    result.turn_advanced = true;
    result.message = "You close the door.";
    return result;
}

// ============================================================================
// Turn Management
// ============================================================================

advance_turn :: (gs: *GameState) {
    gs.turn += 1;
    calculate_fov(*gs.dungeon, gs.player_x, gs.player_y);
}

// ============================================================================
// Helpers
// ============================================================================

// Place player at first room center, or nearest passable tile.
// Room center may be occupied by a pillar (castle rooms), so we search nearby.
game_init_player_position :: (gs: *GameState) {
    m := *gs.dungeon;
    if m.rooms.count > 0 {
        cx, cy := rect_center(m.rooms[0].bounds);

        // If center is passable, use it
        if game_can_move_to(m, cx, cy) {
            gs.player_x = cx;
            gs.player_y = cy;
            return;
        }

        // Search outward from center within the room bounds
        r := m.rooms[0].bounds;
        for radius: 1..max(rect_width(r), rect_height(r)) {
            for dy: -radius..radius {
                for dx: -radius..radius {
                    if abs(dx) != radius && abs(dy) != radius continue;  // Only check perimeter
                    nx := cx + dx;
                    ny := cy + dy;
                    if rect_contains(r, nx, ny) && game_can_move_to(m, nx, ny) {
                        gs.player_x = nx;
                        gs.player_y = ny;
                        return;
                    }
                }
            }
        }
    }

    // Fallback: find any floor tile
    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            if game_can_move_to(m, x, y) {
                gs.player_x = x;
                gs.player_y = y;
                return;
            }
        }
    }

    // Ultimate fallback: center of map
    gs.player_x = m.width / 2;
    gs.player_y = m.height / 2;
}

// Find DoorInfo for a given position (or null if no door tracked there)
find_door_info :: (m: *GenMap, x: s32, y: s32) -> *DoorInfo {
    for *door: m.doors {
        if door.x == x && door.y == y return door;
    }
    return null;
}
