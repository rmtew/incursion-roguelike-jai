// Visibility System - FOV and Lighting Calculations
//
// Implements field of view (FOV) calculation and torch-based lighting.
// Based on original Incursion's Vision.cpp and MakeLev.cpp.
//
// Note: This file is loaded by main.jai which handles all imports.

// Vision constants
SIGHT_RANGE  :: 15;   // Maximum vision distance in lit areas
LIGHT_RANGE  :: 4;    // Personal light source radius (player's torch)
SHADOW_RANGE :: 8;    // Dim perception range (can see shapes, not details)

// Torch/lighting constants
TORCH_RADIUS :: 7;    // How far torch light reaches

// ============================================================================
// Line of Sight
// ============================================================================

// Check if there's a clear line of sight between two points
// Uses Bresenham's line algorithm, stops at opaque terrain
has_line_of_sight :: (m: *GenMap, x0: s32, y0: s32, x1: s32, y1: s32) -> bool {
    dx := abs(x1 - x0);
    dy := abs(y1 - y0);

    sx: s32 = ifx x0 < x1 then cast(s32)1 else cast(s32)-1;
    sy: s32 = ifx y0 < y1 then cast(s32)1 else cast(s32)-1;

    err := dx - dy;

    x := x0;
    y := y0;

    while true {
        // Skip the starting point for blocking check
        if x != x0 || y != y0 {
            // Check if this cell blocks vision
            if is_vision_blocking(m, x, y) {
                return false;
            }
        }

        // Reached destination?
        if x == x1 && y == y1 {
            return true;
        }

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

// Check if terrain blocks vision
is_vision_blocking :: (m: *GenMap, x: s32, y: s32) -> bool {
    t := map_get(m, x, y);
    // Solid terrain blocks vision (walls, rock, closed doors, pillars)
    return terrain_solid(t);
}

// ============================================================================
// Lighting Calculation
// ============================================================================

// Calculate which cells are lit by torches
// Call this after dungeon generation, before FOV calculation
calculate_lighting :: (m: *GenMap) {
    // Clear all lit flags
    for *vis: m.visibility {
        vis.lit = false;
    }

    // For each torch, mark cells within radius as lit
    for torch: m.torch_positions {
        // Light cells in a square around the torch
        for dy_idx: 0..TORCH_RADIUS*2 {
            for dx_idx: 0..TORCH_RADIUS*2 {
                dx := cast(s32)dx_idx - TORCH_RADIUS;
                dy := cast(s32)dy_idx - TORCH_RADIUS;
                x := torch.x + dx;
                y := torch.y + dy;

                if !map_in_bounds(m, x, y) continue;

                // Use Chebyshev distance (max of |dx|, |dy|)
                dist := max(abs(dx), abs(dy));
                if dist > TORCH_RADIUS continue;

                // Check line of sight from torch to cell
                if has_line_of_sight(m, torch.x, torch.y, x, y) {
                    idx := y * m.width + x;
                    m.visibility[idx].lit = true;
                }
            }
        }
    }
}

// ============================================================================
// Field of View Calculation
// ============================================================================

// Visibility flag mask (for clearing VI_VISIBLE while keeping other flags)
VI_VISIBLE_MASK :: cast(u8) 0xFE;  // ~VI_VISIBLE as u8

// Calculate FOV from a position (typically player position)
// Marks cells as VI_VISIBLE and VI_DEFINED, stores memory glyphs
calculate_fov :: (m: *GenMap, px: s32, py: s32) {
    // Clear VI_VISIBLE for all cells (keep VI_DEFINED)
    for *vis: m.visibility {
        vis.flags &= VI_VISIBLE_MASK;
    }

    // Mark player's cell as visible
    mark_visible(m, px, py);

    // Cast rays to cells at maximum vision distance
    // Using a circular pattern around the player
    for angle: 0..359 {
        // Calculate direction
        rad := cast(float32)angle * 0.0174533;  // degrees to radians
        dx := cos(rad);
        dy := sin(rad);

        // Cast ray
        for dist: 1..SIGHT_RANGE {
            x := px + cast(s32)(dx * cast(float32)dist + 0.5);
            y := py + cast(s32)(dy * cast(float32)dist + 0.5);

            if !map_in_bounds(m, x, y) break;

            // Check visibility based on lighting
            idx := y * m.width + x;
            is_lit := m.visibility[idx].lit;

            // Can see if:
            // 1. Within personal light range, OR
            // 2. Cell is lit and within sight range
            can_see := dist <= LIGHT_RANGE || (is_lit && dist <= SIGHT_RANGE);

            // For shadow range (beyond light range but within shadow range and unlit)
            // we still mark VI_DEFINED but not VI_VISIBLE
            if !can_see && dist <= SHADOW_RANGE {
                // Mark as defined (seen as shadow) but not fully visible
                if has_line_of_sight(m, px, py, x, y) {
                    m.visibility[idx].flags |= VI_DEFINED;
                    // Store memory glyph if not already stored
                    if m.visibility[idx].memory_glyph == 0 {
                        glyph, fg, bg := get_terrain_render(m, x, y);
                        m.visibility[idx].memory_glyph = glyph;
                        m.visibility[idx].memory_fg = fg;
                    }
                }
            }

            if can_see {
                if has_line_of_sight(m, px, py, x, y) {
                    mark_visible(m, x, y);
                }
            }

            // Stop ray if hit opaque terrain
            if is_vision_blocking(m, x, y) break;
        }
    }
}

// Mark a cell as visible and store memory
mark_visible :: (m: *GenMap, x: s32, y: s32) {
    if !map_in_bounds(m, x, y) return;

    idx := y * m.width + x;
    vis := *m.visibility[idx];
    vis.flags |= VI_VISIBLE | VI_DEFINED;

    // Store current terrain appearance in memory
    // (creatures and items are not stored - only terrain/features)
    glyph, fg, bg := get_terrain_render(m, x, y);
    vis.memory_glyph = glyph;
    vis.memory_fg = fg;
}

// Get terrain-only render (without creatures/items) for memory storage
get_terrain_render :: (m: *GenMap, x: s32, y: s32) -> u16, u8, u8 {
    terrain := map_get(m, x, y);

    // Start with terrain defaults
    glyph := terrain_glyph(terrain);
    fg_color := get_terrain_fg_color(terrain);
    bg_color := get_terrain_bg_color(terrain);

    // Check for custom tile display (from region terrain)
    td := map_get_display(m, x, y);
    if td != null && td.use_custom {
        glyph = td.glyph;
        fg_color = cast(u8) td.fg_color;
    }

    return glyph, fg_color, bg_color;
}

// ============================================================================
// Visibility Helpers
// ============================================================================

// Check if a cell is currently visible
is_visible :: (m: *GenMap, x: s32, y: s32) -> bool {
    if !map_in_bounds(m, x, y) return false;
    idx := y * m.width + x;
    return (m.visibility[idx].flags & VI_VISIBLE) != 0;
}

// Check if a cell has ever been seen
is_defined :: (m: *GenMap, x: s32, y: s32) -> bool {
    if !map_in_bounds(m, x, y) return false;
    idx := y * m.width + x;
    return (m.visibility[idx].flags & VI_DEFINED) != 0;
}

// Check if a cell is lit
is_lit :: (m: *GenMap, x: s32, y: s32) -> bool {
    if !map_in_bounds(m, x, y) return false;
    idx := y * m.width + x;
    return m.visibility[idx].lit;
}

// Get visibility info for a cell
get_visibility :: (m: *GenMap, x: s32, y: s32) -> *VisibilityInfo {
    if !map_in_bounds(m, x, y) return null;
    return *m.visibility[y * m.width + x];
}

// Clear all visibility (for new level)
clear_visibility :: (m: *GenMap) {
    for *vis: m.visibility {
        vis.flags = 0;
        vis.memory_glyph = 0;
        vis.memory_fg = 0;
        vis.lit = false;
    }
}

// Reveal entire map (debug/cheat mode)
reveal_all :: (m: *GenMap) {
    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            mark_visible(m, x, y);
        }
    }
}
