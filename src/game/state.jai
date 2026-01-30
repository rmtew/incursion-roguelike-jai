// Game State Types
//
// Core types for the game loop: GameState, Action, ActionResult.
// GameState owns a dungeon map and player position. The full Player/Creature
// hierarchy is wired up later when combat/stats are added.

// ============================================================================
// Action Enum
// ============================================================================

Action :: enum u8 {
    NONE;
    MOVE_N;
    MOVE_S;
    MOVE_E;
    MOVE_W;
    MOVE_NE;
    MOVE_NW;
    MOVE_SE;
    MOVE_SW;
    WAIT;
    OPEN_DOOR;
    CLOSE_DOOR;
}

action_to_string :: (a: Action) -> string {
    if a == {
        case .NONE;       return "NONE";
        case .MOVE_N;     return "MOVE_N";
        case .MOVE_S;     return "MOVE_S";
        case .MOVE_E;     return "MOVE_E";
        case .MOVE_W;     return "MOVE_W";
        case .MOVE_NE;    return "MOVE_NE";
        case .MOVE_NW;    return "MOVE_NW";
        case .MOVE_SE;    return "MOVE_SE";
        case .MOVE_SW;    return "MOVE_SW";
        case .WAIT;       return "WAIT";
        case .OPEN_DOOR;  return "OPEN_DOOR";
        case .CLOSE_DOOR; return "CLOSE_DOOR";
    }
    return "UNKNOWN";
}

string_to_action :: (s: string) -> Action, bool {
    if s == {
        case "NONE";       return .NONE, true;
        case "MOVE_N";     return .MOVE_N, true;
        case "MOVE_S";     return .MOVE_S, true;
        case "MOVE_E";     return .MOVE_E, true;
        case "MOVE_W";     return .MOVE_W, true;
        case "MOVE_NE";    return .MOVE_NE, true;
        case "MOVE_NW";    return .MOVE_NW, true;
        case "MOVE_SE";    return .MOVE_SE, true;
        case "MOVE_SW";    return .MOVE_SW, true;
        case "WAIT";       return .WAIT, true;
        case "OPEN_DOOR";  return .OPEN_DOOR, true;
        case "CLOSE_DOOR"; return .CLOSE_DOOR, true;
    }
    return .NONE, false;
}

// Get the direction offset for a movement action
action_to_delta :: (a: Action) -> s32, s32 {
    if a == {
        case .MOVE_N;  return  0, -1;
        case .MOVE_S;  return  0,  1;
        case .MOVE_E;  return  1,  0;
        case .MOVE_W;  return -1,  0;
        case .MOVE_NE; return  1, -1;
        case .MOVE_NW; return -1, -1;
        case .MOVE_SE; return  1,  1;
        case .MOVE_SW; return -1,  1;
    }
    return 0, 0;
}

// Get the Dir enum value for a movement action
action_to_dir :: (a: Action) -> Dir {
    if a == {
        case .MOVE_N;  return .NORTH;
        case .MOVE_S;  return .SOUTH;
        case .MOVE_E;  return .EAST;
        case .MOVE_W;  return .WEST;
        case .MOVE_NE; return .NORTHEAST;
        case .MOVE_NW; return .NORTHWEST;
        case .MOVE_SE; return .SOUTHEAST;
        case .MOVE_SW; return .SOUTHWEST;
    }
    return .CENTER;
}

// Check if an action is a movement action
is_move_action :: (a: Action) -> bool {
    return a >= .MOVE_N && a <= .MOVE_SW;
}

// ============================================================================
// ActionResult
// ============================================================================

ActionResult :: struct {
    success: bool;
    message: string;
    turn_advanced: bool;
    door_opened: bool;
    blocked_reason: string;
}

// ============================================================================
// GameState
// ============================================================================

GameState :: struct {
    dungeon: GenMap;
    seed: u64;
    depth: s32;
    player_x: s32;
    player_y: s32;
    turn: s32;
    rng: MT19937;       // Dedicated game-phase RNG, isolated from generation RNG
    initialized: bool;
}
