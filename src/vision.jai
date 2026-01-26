// Incursion Port - Vision System
// Reconstructed from RECONSTRUCTION-CORE.md

// Line of sight using Bresenham-like algorithm
has_los :: (m: *Map, x1: s32, y1: s32, x2: s32, y2: s32) -> bool {
    dx := my_abs(x2 - x1);
    dy := my_abs(y2 - y1);

    sx: s32 = 1;
    if x1 > x2 sx = -1;
    sy: s32 = 1;
    if y1 > y2 sy = -1;

    err := dx - dy;

    x := x1;
    y := y1;

    while true {
        // Check if blocked (but allow endpoints)
        if (x != x1 || y != y1) && (x != x2 || y != y2) {
            if map_is_opaque(m, x, y) return false;
        }

        if x == x2 && y == y2 break;

        e2 := 2 * err;
        if e2 > -dy {
            err -= dy;
            x += sx;
        }
        if e2 < dx {
            err += dx;
            y += sy;
        }
    }

    return true;
}

// Distance functions
chebyshev_distance :: (x1: s32, y1: s32, x2: s32, y2: s32) -> s32 {
    dx := my_abs(x2 - x1);
    dy := my_abs(y2 - y1);
    return my_max(dx, dy);
}

manhattan_distance :: (x1: s32, y1: s32, x2: s32, y2: s32) -> s32 {
    dx := my_abs(x2 - x1);
    dy := my_abs(y2 - y1);
    return dx + dy;
}

euclidean_dist_squared :: (x1: s32, y1: s32, x2: s32, y2: s32) -> s32 {
    dx := x2 - x1;
    dy := y2 - y1;
    return dx*dx + dy*dy;
}

// Direction from one point to another
direction_to :: (x1: s32, y1: s32, x2: s32, y2: s32) -> Dir {
    dx := x2 - x1;
    dy := y2 - y1;

    // Normalize to -1, 0, 1
    sx: s32 = 0;
    if dx > 0 sx = 1;
    else if dx < 0 sx = -1;

    sy: s32 = 0;
    if dy > 0 sy = 1;
    else if dy < 0 sy = -1;

    if sx == 0 && sy == 0 return .CENTER;
    if sx == 0 && sy == -1 return .NORTH;
    if sx == 0 && sy == 1 return .SOUTH;
    if sx == 1 && sy == 0 return .EAST;
    if sx == -1 && sy == 0 return .WEST;
    if sx == 1 && sy == -1 return .NORTHEAST;
    if sx == -1 && sy == -1 return .NORTHWEST;
    if sx == 1 && sy == 1 return .SOUTHEAST;
    if sx == -1 && sy == 1 return .SOUTHWEST;

    return .CENTER;
}

// Opposite direction
opposite_dir :: (d: Dir) -> Dir {
    if d == .NORTH return .SOUTH;
    if d == .SOUTH return .NORTH;
    if d == .EAST return .WEST;
    if d == .WEST return .EAST;
    if d == .NORTHEAST return .SOUTHWEST;
    if d == .NORTHWEST return .SOUTHEAST;
    if d == .SOUTHEAST return .NORTHWEST;
    if d == .SOUTHWEST return .NORTHEAST;
    if d == .UP return .DOWN;
    if d == .DOWN return .UP;
    return .CENTER;
}
